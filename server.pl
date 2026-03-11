#!/usr/bin/env perl
use Mojolicious::Lite -signatures;
use File::Temp qw(tempfile);
use File::Basename;

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

    # Run processGPX using list form to avoid shell injection
    my @cmd = (
        'perl', $process_gpx,
        '--auto', '--simplify', '--fitArcs', '--arcInterpolation',
        '-out', $out_file,
        $in_file
    );

    my $pid = open(my $pipe, '-|');
    if (!defined $pid) {
        return $c->render(text => 'Failed to fork', status => 500);
    }
    if ($pid == 0) {
        # Child: redirect stderr to stdout, exec
        open(STDERR, '>&', STDOUT);
        exec(@cmd);
        die "exec failed: $!";
    }
    my $output = do { local $/; <$pipe> };
    close $pipe;
    my $exit_code = $? >> 8;

    if ($exit_code != 0) {
        app->log->error("processGPX failed (exit $exit_code): $output");
        return $c->render(text => "Processing failed: $output", status => 500);
    }

    # Read and return the processed GPX
    open(my $fh, '<', $out_file) or do {
        return $c->render(text => 'Failed to read processed output', status => 500);
    };
    my $result = do { local $/; <$fh> };
    close $fh;

    # Clean up temp files
    unlink $in_file, $out_file;

    $c->res->headers->content_type('application/gpx+xml');
    $c->render(data => $result);
};

# Listen on PORT env var (Cloud Run sets this) or default 8080
my $port = $ENV{PORT} || 8080;
app->start('daemon', '-l', "http://*:$port");
