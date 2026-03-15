#!/usr/bin/env perl
use Mojolicious::Lite -signatures;
use File::Temp qw(tempfile);
use File::Basename;

# Production mode: skip debug templates on 404s
app->mode('production');
app->log->level('warn');

my $MAX_UPLOAD = 5 * 1024 * 1024; # 5 MiB

# Find the processGPX script relative to this server
my $script_dir = dirname(__FILE__);
my $process_gpx = "$script_dir/processGPX";
die "processGPX not found at $process_gpx\n" unless -f $process_gpx;

# Configure upload size limit
app->max_request_size($MAX_UPLOAD + 4096); # small overhead for multipart headers

# Serve static files from web/
app->static->paths->[0] = "$script_dir/web";

# Root serves index.html
get '/' => sub ($c) {
    $c->reply->static('index.html');
};

# Process GPX endpoint
post '/process' => sub ($c) {
    my $upload = $c->req->upload('gpx');
    unless ($upload) {
        return $c->render(text => 'No GPX file uploaded', status => 400);
    }

    my $size = $upload->size;
    if ($size > $MAX_UPLOAD) {
        return $c->render(text => 'File exceeds 5 MB limit', status => 413);
    }

    # Write upload to temp file
    my ($in_fh, $in_file) = tempfile(SUFFIX => '.gpx', UNLINK => 1);
    print $in_fh $upload->slurp;
    close $in_fh;

    # Create temp file for output
    my ($out_fh, $out_file) = tempfile(SUFFIX => '.gpx', UNLINK => 1);
    close $out_fh;

    # Parse client-supplied options (JSON array of strings)
    my @user_opts;
    if (my $opts_json = $c->req->param('options')) {
        my $opts = eval { Mojo::JSON::decode_json($opts_json) };
        if (ref $opts eq 'ARRAY') {
            # Whitelist: only allow options starting with - and values
            # Filter out dangerous options like -out, -o, -noSave
            my %blocked = map { $_ => 1 } qw(-out -o --out --o -noSave -nosave -csv -quiet -v -version --version -help --help);
            my $skip_next = 0;
            for my $arg (@$opts) {
                if ($skip_next) { $skip_next = 0; next; }
                if ($blocked{$arg}) {
                    # Skip this option and its value if it takes one
                    $skip_next = 1 if $arg =~ /^-(?:out|o)$/i;
                    next;
                }
                push @user_opts, $arg;
            }
        }
    }

    # If no user options, use defaults
    if (!@user_opts) {
        @user_opts = ('--auto', '--simplify', '--fitArcs', '--arcInterpolation');
    }

    # Run processGPX using list form, capturing stdout+stderr
    my @cmd = (
        'perl', $process_gpx,
        @user_opts,
        '-out', $out_file,
        $in_file
    );

    # Capture stderr into a temp file so we can read it after the process exits
    my ($err_fh, $err_file) = tempfile(SUFFIX => '.err', UNLINK => 1);
    close $err_fh;

    my $pid = open(my $pipe, '-|');
    if (!defined $pid) {
        unlink $err_file;
        return $c->render(text => 'Failed to run processGPX', status => 422);
    }
    if ($pid == 0) {
        open(STDERR, '>', $err_file);
        exec(@cmd);
        die "exec failed: $!";
    }
    my $stdout = do { local $/; <$pipe> };
    close $pipe;
    my $exit_code = $? >> 8;

    # Read captured stderr
    my $stderr = '';
    if (open(my $efh, '<', $err_file)) {
        $stderr = do { local $/; <$efh> };
        close $efh;
    }
    unlink $err_file;
    my $output = $stderr . $stdout;

    if ($exit_code != 0) {
        my @lines;
        for my $line (split /\n/, $output) {
            last if $line =~ /^Uncaught exception/;
            push @lines, $line if $line =~ /\S/;
        }
        my $msg = join("\n", @lines) || "processGPX exited with code $exit_code";
        app->log->error("processGPX failed (exit $exit_code): $output");
        return $c->render(text => $msg, status => 422);
    }

    # Read and return the processed GPX
    my $result;
    if (open(my $fh, '<', $out_file)) {
        $result = do { local $/; <$fh> };
        close $fh;
    }
    unless ($result && length($result) > 0) {
        my $msg = $output || 'processGPX produced no output';
        return $c->render(text => $msg, status => 422);
    }

    # Clean up temp files
    unlink $in_file, $out_file;

    $c->render(json => { gpx => $result, log => $output });
};

# Version endpoint (cached at startup)
my $version = `perl $process_gpx --version 2>&1`;
chomp $version;
$version =~ s/.*version\s*//i;

get '/version' => sub ($c) {
    $c->render(text => $version);
};

# Serve the HTML manual from the repo root
get '/manual' => sub ($c) {
    open(my $fh, '<', "$script_dir/processGPX.html") or do {
        return $c->render(text => 'Manual not found', status => 404);
    };
    my $html = do { local $/; <$fh> };
    close $fh;
    $c->render(data => $html, format => 'html');
};

# Catch-all: return minimal 404 for any unmatched path (shuts down probes fast)
any '/*whatever' => { whatever => '' } => sub ($c) {
    $c->render(text => 'Not Found', status => 404);
};

# Listen on PORT env var (Cloud Run sets this) or default 8080
my $port = $ENV{PORT} || 8080;
app->start('daemon', '-l', "http://*:$port");
