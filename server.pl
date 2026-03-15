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
        require JSON;
        my $opts = eval { JSON::decode_json($opts_json) };
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

    # Run processGPX, capturing both stdout and stderr
    my @cmd = (
        'perl', $process_gpx,
        @user_opts,
        '-out', $out_file,
        $in_file
    );

    # Use IPC to capture stdout+stderr together
    my ($out_read, $out_write);
    pipe($out_read, $out_write) or do {
        return $c->render(text => 'Failed to create pipe', status => 422);
    };

    my $pid = fork();
    if (!defined $pid) {
        return $c->render(text => 'Failed to fork', status => 422);
    }
    if ($pid == 0) {
        close $out_read;
        open(STDOUT, '>&', $out_write);
        open(STDERR, '>&', $out_write);
        close $out_write;
        exec(@cmd);
        die "exec failed: $!";
    }
    close $out_write;
    my $output = do { local $/; <$out_read> };
    close $out_read;
    waitpid($pid, 0);
    my $exit_code = $? >> 8;

    if ($exit_code != 0) {
        # Extract meaningful lines from script output (skip blank lines)
        my @lines = grep { /\S/ } split /\n/, $output;
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

# Catch-all: return minimal 404 for any unmatched path (shuts down probes fast)
any '/*whatever' => { whatever => '' } => sub ($c) {
    $c->render(text => 'Not Found', status => 404);
};

# Listen on PORT env var (Cloud Run sets this) or default 8080
my $port = $ENV{PORT} || 8080;
app->start('daemon', '-l', "http://*:$port");
