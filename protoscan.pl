#!/usr/bin/perl
# Protoscan - Proxy Fetcher and Protocol Scanner Tool
# Copyright (C) 2013 Amine Belgacem

# The tool proposes the following utilities:
# - [scan] Scan proxy servers to detect their communication protocols.
# - [fetch] Retrieve proxy servers from specified URL sources.

# Note: The tool was tested on Win64/32, Linux/MacOS may need adjustments.
# Note: 'maxmind4.dat' is a GeoIP database and needs to be updated manually.
# Latest GeoIP database can be downloaded from https://www.miyuru.lk/geoiplegacy

# This tool is intended for lawful purposes exclusively. Users bear complete
# responsibility for any activities conducted with this tool. The author
# assumes no responsibility for any harm caused by the use of this tool.
# If you do not agree with these terms, you are not authorized to use this tool.

use strict;
use warnings;
use 5.010;
use File::Basename;
use IO::Socket::INET;
use threads;
use Thread::Queue;
use Errno qw(ETIMEDOUT EWOULDBLOCK);
use POSIX qw(strerror);
use Time::HiRes qw(time);
use AutoLoader qw/AUTOLOAD/;
use HTTP::Status;
use NetAddr::IP::Util qw(inet_aton);
use Data::Validate::URI;
use Getopt::Long;
use LWP::UserAgent;
use Geo::IP;

# Global configuration

my $Target        = 'www.google.com';
my $GeoipDatabase = './maxmind4.dat';

# Helper subroutines:

# Trims leading and trailing spaces from a string.
sub trim {
    my $string = shift;
    $string =~ s/^\s+|\s+$//g;

    return $string;
}

# Gets the domain name from a URL.
sub getDomainFromURL {
    my ($url) = @_;

    $url =~ s/^(https?:\/\/)?//;
    my ($domain) = $url =~ /^([\w.-]+)/;

    return $domain;
}

# Pads the given string on the right side with spaces.
sub padRight {
    my ($string, $length) = @_;

    foreach (length($string) .. $length) {
        $string .= ' ';
    }

    return $string;
}

# Shortens domain name if it exceeds 20 characters.
sub shortenDomain {
    my $domain = shift;
    my $shortDomain;

    if (length($domain) > 21) {
        $shortDomain = substr($domain, 0, 17) . '...';
    } else {
        $shortDomain = $domain;
    }

    return $shortDomain;
}

# Retrieve the ISO country code for a given IP address
sub ipToCountry {
    my $ip = shift;
    isFile($GeoipDatabase);

    my $geoip = Geo::IP->open($GeoipDatabase, GEOIP_STANDARD);

    my $countryCode = $geoip->country_code3_by_addr($ip);

    return $countryCode if (defined($countryCode));
    return 'Unknown';
}

# Prints a formatted row with optional columns to the console
sub printRow {
    my $string = $_[0] . " ";
    $string .= padRight($_[1], 24);
    $string .= padRight($_[2], 10);
    $string .= padRight($_[3], 10) if defined($_[3]);
    $string .= padRight($_[4], 10) if defined($_[4]);

    print "$string\n";
}

# Type validation subroutines:

# Check if value exists in an array.
sub isInArray {
    my @array     = @{ $_[0] };
    my $value     = $_[1];
    my %arrayHash = map { $_ => 1 } @array;

    return exists($arrayHash{$value});
}

# Checks if folder exists.
sub isFolder {
    my $folder = dirname(shift);

    die "'$folder' folder does not exist.\n" if (!-d $folder);

    return 1;
}

# Checks if file exists, not empty, readable, and writable.
sub isFile {
    my $filePath = shift;
    my $fileName = basename($filePath);

    die "'$fileName' file does not exist.\n"  if (!-e $filePath);
    die "'$fileName' file is empty.\n"        if (-z $filePath);
    die "'$fileName' file is not readable.\n" if (!-r $filePath);
    die "'$fileName' file is not writable.\n" if (!-w $filePath);

    return 1;
}

# Checks if argument is a valid IP address.
sub isIP {
    my $ip      = shift;
    my $ipRegex = qr/
        (?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]
        |2[0-4][0-9]|[01]?[0-9][0-9]?)
    /x;

    return ($ip =~ /(\b^$ipRegex\b$)/) ? 1 : 0;
}

# Checks if argument is a valid domain name.
sub isDomain {
    my $domain      = shift;
    my $domainRegex = qr/^((([a-z]|[0-9]|\-)+)\.)+([a-z])+$/;

    return ($domain =~ /(\b^$domainRegex\b$)/) ? 1 : 0;
}

# Checks if argument is a valid network port.
sub isPort {
    my $port      = shift;
    my $portRegex = qr/
        6553[0-5]|655[0-2]\d|65[0-4]\d\d|
        6[0-4]\d\d\d|[1-5]\d\d\d\d|[1-9]\d?\d?\d?|0
    /x;

    return (($port =~ /(\b^$portRegex\b$)/) && $port > 0) ? 1 : 0;
}

# Checks if argument is a valid proxy line.
sub isProxy {
    my ($proxy) = shift;
    my ($ip, $port) = split /:/, $proxy;

    return defined($ip) && isIP($ip) && defined($port) && isPort($port);
}

# Checks if argument is a valid URL.
sub isURL {
    my $url       = shift;
    my $validator = new Data::Validate::URI();
    return ($validator->is_http_uri($url) or $validator->is_https_uri($url));
}

# File-related subroutines:

# Opens file and returns file handle.
sub openFile {
    my $filePath = shift;
    my $mode     = shift;
    my $fileHandle;

    open($fileHandle, $mode, $filePath)
        or die "Could not open file '" . basename($filePath) . "': $!\n";

    return $fileHandle;
}

# Closes file handle.
sub closeFile {
    my $fileHandle = shift;
    my $filePath   = shift;

    close $fileHandle
        or die "Could not close file '" . basename($filePath) . "': $!\n";

    return 1;
}

# Appends a string to file.
sub printFile {
    my $fileHandle = shift;
    my $string     = shift;

    print {$fileHandle} $string;

    return 1;
}

# Reads file lines into an array.
sub readFileIntoArray {
    my $filePath   = shift;
    my $fileHandle = openFile($filePath, '<:encoding(utf8)');

    chomp(my @array = <$fileHandle>);

    closeFile($fileHandle, $filePath);

    return @array;
}

# Reads the contents of a file and applies validation to each line.
sub getFileContent {
    my $filePath = shift;

    my $validate = shift;
    my $filename = basename($filePath);

    my @fileContent = readFileIntoArray($filePath);
    my @contentList;

    foreach (@fileContent) {
        push(@contentList, trim($_)) if (&$validate(trim($_)));
    }

    die "0 records found in '$filename'\n" if (scalar(@contentList) == 0);

    print "> Importing records from file...\n";
    print "> " . scalar(@contentList) . " records imported from '$filename'\n\n";
    return @contentList;
}

# Reads a text file and removes duplicate lines.
sub removeDuplicatesFromFile {
    my $filePath       = shift;
    my $duplicateCount = 0;
    my %seen;

    my @lines      = readFileIntoArray($filePath);
    my $fileHandle = openFile($filePath, '>');

    foreach my $line (@lines) {
        chomp $line;
        unless ($seen{$line}) {
            print $fileHandle "$line\n";
            $seen{$line} = 1;
        } else {
            $duplicateCount++;
        }
    }

    closeFile($fileHandle);

    return $duplicateCount;
}

# Socket related subroutines:

# Establishes a socket connection with retry and timing measurement.
sub socketConnect {
    my ($ip, $port, $timeout, $retries, $getLatency) = @_;
    my $winReuseError = 'A connect request was made on an already connected socket';

    for my $retry (0 .. $retries) {
        my $startTime = time();
        my $socket    = IO::Socket::INET->new(
            Proto    => 'TCP',
            PeerAddr => $ip,
            PeerPort => $port,
            Timeout  => $timeout,
            Blocking => 0
       );

        if (defined($socket)) {
            my $latency = int((time() - $startTime) * 1000);
            return ($socket, $latency) if $getLatency;
            return $socket;
        }

        last if $! ne '' && $! ne strerror(ETIMEDOUT) && $! ne $winReuseError;
    }

    return undef;
}

# Writes data to a socket with retry and error handling.
sub socketWrite {
    my ($socket, $timeout, $retries, $message) = @_;

    for my $retry (0 .. $retries) {
        my $selector = IO::Select->new($socket);
        if ($selector->can_write($timeout)) {
            my $result = $socket->syswrite($message);
            return $result if defined($result) && $result == length($message);
            last unless ($! eq strerror(EWOULDBLOCK) or $! eq strerror(ETIMEDOUT));
        }
    }

    return undef;
}

# Reads data from a socket with retry and error handling.
sub socketRead {
    my ($socket, $timeout, $retries, $buffer, $limit) = @_;

    for my $retry (0 .. $retries) {
        my $selector = IO::Select->new($socket);
        if ($selector->can_read($timeout)) {
            my $result = $socket->sysread($$buffer, $limit);
            return $result if defined($result) and $result >= 0;
            last unless ($! eq strerror(EWOULDBLOCK) or $! eq strerror(ETIMEDOUT));
        }
    }

    return undef;
}

# Communicates with a socket by sending a request and receiving a response.
sub socketCommunicate {
    my ($socket, $timeout, $retries, $request, $limit) = @_;

    my $buffer;
    socketWrite($socket, $timeout, $retries, $request);
    socketRead($socket, $timeout, $retries, \$buffer, $limit);

    return $buffer;
}

# HTTP related subroutines:

# Performs an HTTP GET request and check the response status.
sub getHttp {
    my ($socket, $timeout, $retries) = @_;
    my $CRLF    = "\r\n";
    my $request = "GET http://$Target:80 HTTP/1.1$CRLF" . "Host: $Target$CRLF$CRLF";
    my $reply   = socketCommunicate($socket, $timeout, $retries, $request, 12);

    if (defined($reply) && length($reply) >= 12 && substr($reply, 0, 8) eq 'HTTP/1.1') {
        my $statusCode = substr($reply, 9, 3);
        return 1 if is_success($statusCode);
    }

    return 0;
}

# Checks if the given IP and port represent a HTTP server
sub isHttp {
    my ($ip, $port, $timeout, $retries) = @_;
    my $socket = socketConnect($ip, $port, $timeout, $retries, 0);

    return getHttp($socket, $timeout, $retries) if $socket;
    return 0;
}

# HTTPS related subroutines:

# Performs a CONNECT request and check the response status.
sub connectToHttps {
    my ($socket, $timeout, $retries) = @_;
    my $CRLF    = "\r\n";
    my $request = "CONNECT $Target:443 HTTP/1.1$CRLF" . "Host: $Target$CRLF$CRLF";
    my $reply   = socketCommunicate($socket, $timeout, $retries, $request, 12);

    if (defined($reply) && length($reply) >= 12 && substr($reply, 0, 8) eq 'HTTP/1.1') {
        my $statusCode = substr($reply, 9, 3);
        return 1 if defined(status_message($statusCode)) && is_success($statusCode);
    }

    return 0;
}

# Checks if the given IP and port represent a HTTPS server
sub isHttps {
    my ($ip, $port, $timeout, $retries) = @_;
    my $socket = socketConnect($ip, $port, $timeout, $retries, 0);

    return connectToHttps($socket, $timeout, $retries) if $socket;
    return 0;
}

# SOCKS4 related subroutines:

# Performs a CONNECT request and check the response status.
sub connectToSocks4 {
    my ($socket, $timeout, $retries) = @_;
    my $destIP         = inet_aton($Target);
    my $targetPort     = pack('n', '80');
    my $request        = "\x04\x01" . $targetPort . $destIP . "\x00";
    my $reply          = socketCommunicate($socket, $timeout, $retries, $request, 8);
    my @connectResults = ("\x5A", "\x5B", "\x5C", "\x5D");

    if (defined($reply) && length($reply) == 8) {
        if (substr($reply, 0, 1) eq "\x00") {
            my $result = substr($reply, 1, 1);

            if (grep { $_ eq $result } @connectResults) {
                my $bndPort = unpack("n", substr($reply, 2, 2));
                my $bndHost = substr($reply, 4, 4);
                $bndHost = join('.', unpack("C*", $bndHost));

                return 1 if (isPort($bndPort) and isIP($bndHost) and $result eq "\x5A");
            }
        }
    }

    return 0;
}

# Checks if the given IP and port represent a SOCKS4 server
sub isSocks4 {
    my ($ip, $port, $timeout, $retries) = @_;
    my $socket = socketConnect($ip, $port, $timeout, $retries, 0);

    return connectToSocks4($socket, $timeout, $retries) if $socket;
    return 0;
}

# SOCKS5 related subroutines:

# Performs a CONNECT request and check the response status.
sub connectToSocks5 {
    my ($socket, $timeout, $retries) = @_;
    my $destIP     = inet_aton($Target);
    my $targetPort = pack('n', '80');
    my $request    = "\x05\x01\x00\x01" . $destIP . $targetPort;
    my $reply      = socketCommunicate($socket, $timeout, $retries, $request, 259);

    if (defined($reply) && length($reply) >= 10 and length($reply) <= 260) {
        my $ver      = substr($reply, 0, 1);
        my $reserved = substr($reply, 2, 1);

        if ($ver eq "\x05" and $reserved eq "\x00") {
            my $atype = substr($reply, 3, 1);

            if ($atype eq "\x01") {
                my $bndAddr = substr($reply, 4, 4);
                $bndAddr = join('.', unpack("C*", $bndAddr));
                my $bndPort = unpack("n", substr($reply, 8, 2));
                return 1 if (isIP($bndAddr) and isPort($bndPort));
            } elsif ($atype eq "\x03") {
                my $bndHostLen = unpack("C", substr($reply, 4, 1));
                my $bndAddr    = substr($reply, 5, $bndHostLen);
                my $bndPort    = unpack("n", substr($reply, $bndHostLen + 5, 2));
                return 1 if (isDomain($bndAddr) and isPort($bndPort));
            } elsif ($atype eq "\x04") {
                my $bndAddr = substr($reply, 4, 16);
                my $bndPort = unpack("n", substr($reply, 20, 2));
                my $bndAddrIPv6;
                try { $bndAddrIPv6 = ipv6_ntoa($bndAddr) };
                return 1 if (defined($bndAddrIPv6) and isPort($bndPort));
            }
        }
    }

    return 0;
}

# Initiates a SOCKS5 proxy negotiation without authentication.
sub socks5NegotiateNoAuth {
    my ($socket, $timeout, $retries) = @_;
    my $request = "\x05\x01\x00";
    my $reply   = socketCommunicate($socket, $timeout, $retries, $request, 2);

    return defined($reply) && length($reply) == 2 && $reply eq "\x05\x00" ? 1 : 0;
}

# Checks if the given IP and port represent a SOCKS5 server
sub isSocks5 {
    my ($ip, $port, $timeout, $retries) = @_;
    my $socket = socketConnect($ip, $port, $timeout, $retries, 0);

    return connectToSocks5($socket, $timeout, $retries)
        if $socket && socks5NegotiateNoAuth($socket, $timeout, $retries);

    return 0;
}

# Processes a list of tasks concurrently using multiple threads.
sub process {
    my @tasks       = @{ $_[0] };
    my $outputFile  = $_[1];
    my $preCallback = $_[2];
    my $callback    = $_[3];
    my $threads     = $_[4];

    my $queue = Thread::Queue->new(@tasks);
    $queue->end();

    print "> Processing " . scalar(@tasks) . " task(s)...\n\n";

    &$preCallback($outputFile) if defined($preCallback);

    my @threads = map {
        threads->create(
            sub {
                my $fileHandle = openFile($outputFile, '>>') if $outputFile;
                while (defined(my $task = $queue->dequeue())) {
                    &$callback($task, $fileHandle);
                }
                closeFile($fileHandle) if defined($fileHandle);
            }
       );
    } 1 .. $threads;

    $_->join foreach (@threads);

    print "\n> Processing ended: " . scalar(@tasks) . " task(s) finished.\n";
    print "> Results exported to '$outputFile'.\n" if $outputFile;
}

# Scan related subroutines:

# Probes a remote host to determine its reachability, latency, and protocol.
sub probeHost {
    my ($ip, $port, $timeout, $retries, $http, $https, $socks4, $socks5) = @_;

    my %result = (
        'reachable' => 0,
        'latency'   => 0,
        'isHttp'    => 0,
        'isHttps'   => 0,
        'isSocks4'  => 0,
        'isSocks5'  => 0,
   );

    my ($socket, $latency) = socketConnect($ip, $port, $timeout, $retries, 1);

    if (defined($socket)) {
        $result{'reachable'} = 1;
        $result{'latency'}   = $latency;
        $result{'country'}   = ipToCountry($ip);
        $result{'isHttp'}    = isHttp($ip, $port, $timeout, $retries)   if ($http);
        $result{'isHttps'}   = isHttps($ip, $port, $timeout, $retries)  if ($https);
        $result{'isSocks4'}  = isSocks4($ip, $port, $timeout, $retries) 
            if ($socks4 && !$result{'isHttp'} && !$result{'isHttps'});
        $result{'isSocks5'}  = isSocks5($ip, $port, $timeout, $retries) 
            if ($socks5 && !$result{'isHttp'} && !$result{'isHttps'});
    }

    return %result;
}

# Parses command line options and returns a hash of scan options.
sub getScanOptions {
    my ($proxy, $proxyFile, $outputFile, $allProtocols);
    my %options = (
        'proxies' => [],
        'threads' => 1,
        'timeout' => 10,
        'retries' => 0,
        'http'    => 0,
        'https'   => 0,
        'socks4'  => 0,
        'socks5'  => 0,
   );

    GetOptions(
        'proxy=s'       => \$proxy,
        'proxy-file=s'  => \$proxyFile,
        'output-file=s' => \$outputFile,
        'threads=i'     => \$options{'threads'},
        'timeout=i'     => \$options{'timeout'},
        'retries=i'     => \$options{'retries'},
        'http!'         => \$options{'http'},
        'https!'        => \$options{'https'},
        'socks4!'       => \$options{'socks4'},
        'socks5!'       => \$options{'socks5'},
        'all!'          => \$allProtocols
   ) or die $PROTOSCAN::usage;

    die("At least one of '-proxy' or '-proxy-file' must be specified.\n")
        unless (defined($proxy) || defined($proxyFile));

    die("Choose either '-proxy' or '-proxy-file', not both.\n")
        if (defined($proxy) && defined($proxyFile));

    if (defined($outputFile)) {
        isFolder($outputFile);
        $options{'outputFile'} = $outputFile;
    }

    if (defined($proxy)) {
        die "Proxy format is not valid.\n" if !isProxy($proxy);
        push @{ $options{'proxies'} }, $proxy;
    } else {
        isFile($proxyFile);
        @{ $options{'proxies'} } = getFileContent($proxyFile, \&isProxy);
    }

    if (defined($allProtocols)) {
        $options{'http'}   = 1;
        $options{'https'}  = 1;
        $options{'socks4'} = 1;
        $options{'socks5'} = 1;
    }

    return %options;
}

# Scans a list of proxy servers for supported protocols
sub scan {
    print "\n[scan] Proxy communication protocol scanner\n\n";

    my %options = getScanOptions();
    my @tasks;

    for my $proxy (@{ $options{'proxies'} }) {
        my ($ip, $port) = split /:/, $proxy;
        my @task = (
            $ip, 
            $port, 
            $options{'timeout'},
            $options{'retries'}, 
            $options{'http'}, 
            $options{'https'}, 
            $options{'socks4'}, 
            $options{'socks5'}
        );
        push(@tasks, \@task);
    }

    process(
        \@tasks,
        $options{'outputFile'},
        sub {
            my $outputFile = shift;

            if (defined($outputFile)) {
                my $fileHandle  = openFile($options{'outputFile'}, '>>');
                my @fileHeaders = ('SRV', 'CTRY', 'LAT(ms)', 'RSLT');
                printFile($fileHandle, join(',', @fileHeaders) . "\n");
            }

            printRow(" ", "SRV", "CTRY", "LAT(ms)", "RSLT");
            print "\n";
        },
        sub {
            my ($task, $fileHandle) = @_;
            my ($ip, $port)         = @$task;
            my $proxy  = "$ip:$port";
            my %result = probeHost(@$task);

            if ($result{'reachable'}) {
                my @protocols;
                push(@protocols, 'HTTP')   if $result{'isHttp'};
                push(@protocols, 'HTTPS')  if $result{'isHttps'};
                push(@protocols, 'SOCKS4') if $result{'isSocks4'};
                push(@protocols, 'SOCKS5') if $result{'isSocks5'};

                my $protocols = @protocols ? join('/', @protocols) : 'Unknown';

                printRow("+", $proxy, $result{'country'}, $result{'latency'}, $protocols);

                if (defined($fileHandle) && @protocols) {
                    printFile(
                        $fileHandle, 
                        "$proxy, $result{'country'}, $result{'latency'}, $protocols\n"
                    );
                }
            } else {
                printRow("-", $proxy, '-', '-', 'Dead');
            }
        },
        $options{'threads'}
   );
}

# Fetch related subroutines:

# Fetches proxy addresses from a given URL.
sub fetchProxyFromURL {
    my ($url, $timeout) = @_;
    my $agent    = LWP::UserAgent->new(timeout => $timeout);
    my $request  = HTTP::Request->new(GET => $url);
    $agent->agent("Mozilla/5.0 (Windows NT 10.0; Win64; x64)");
    my $response = $agent->request($request);

    my @proxies;
    if ($response->is_success) {
        my @lines = ($response->decoded_content =~ /(\d+\.\d+\.\d+\.\d+:\d+)/g);

        foreach my $line (@lines) {
            push @proxies, $line if (isProxy($line));
        }
    }

    return @proxies;
}

# Parses command line options and returns a hash of fetch options.
sub getFetchOptions {
    my ($url, $urlFile, $outputFile);
    my %options = (
        'urls'    => [],
        'threads' => 1,
        'timeout' => 10,
        'limit'   => undef,
   );

    GetOptions(
        'url=s'         => \$url,
        'url-file=s'    => \$urlFile,
        'output-file=s' => \$outputFile,
        'threads=i'     => \$options{'threads'},
        'timeout=i'     => \$options{'timeout'},
        'limit=i'       => \$options{'limit'},
   ) or die $PROTOSCAN::usage;

    die("At least one of '-url' or '-url-file' must be specified.\n")
        unless (defined($url) || defined($urlFile));

    die("Choose either '-url' or '-url-file', not both.\n")
        if (defined($url) && defined($urlFile));

    if (defined($outputFile)) {
        isFolder($outputFile);
        $options{'outputFile'} = $outputFile;
    } else {
        die "-output-file parameter must be specified.\n";
    }

    if (defined($url)) {
        die "URL format is not valid.\n" if !isURL($url);
        push @{ $options{'urls'} }, $url;
    } else {
        isFile($urlFile);
        @{ $options{'urls'} } = getFileContent($urlFile, \&isURL);
    }

    return %options;
}

# Fetches proxy servers from specified URLs.
sub fetch {
    print "\n[fetch] URL-Based Proxy Retrieval Tool\n\n";

    my %options = getFetchOptions();
    my @tasks;

    for my $url (@{ $options{'urls'} }) {
        my @task = ($url, $options{'timeout'}, $options{'limit'});
        push(@tasks, \@task);
    }

    process(
        \@tasks,
        $options{'outputFile'},
        sub {
            printRow(" ", "URL", "RETRV");
            print "\n";
        },
        sub {
            my ($task, $fileHandle) = @_;
            my @result = fetchProxyFromURL(@$task);

            if ($fileHandle) {
                foreach my $result (@result) {
                    printFile($fileHandle, "$result\n");
                }
            }

            printRow("-", shortenDomain(getDomainFromURL(@$task[0])), scalar(@result));
        },
        $options{'threads'}
   );

    print "\n> Removing duplicates from file...\n";
    print "> " . removeDuplicatesFromFile($options{'outputFile'}) . " records removed.\n";
}

# Main:

# Gets main command and calls subroutine.
sub getCommand {
    my $cmd      = shift;
    my @commands = ('scan', 'fetch',);

    if (defined $cmd && isInArray(\@commands, $cmd)) {
        scan()  if $cmd eq 'scan';
        fetch() if $cmd eq 'fetch';
    } else {
        if (not defined $cmd) {
            die "Missing command, unable to continue.\n";
        }
        die "Unknown command, please select a supported command.\n";
    }
}

# Catches die and warn signals.
sub errorWrap {
    my $error = $_[0];
    chomp($error);
    $error .= '.' if (substr($error, length($error) - 1, 1) ne '.');

    if ($error =~ /Terminating on signal SIGINT\(2\)/) {
        print "> CTRL+C interrupt detected. Exiting...\n";
        exit(1);
    } else {
        print "> Error: $error\n";
        print $PROTOSCAN::usage;
        exit(1);
    }
}
$SIG{__WARN__} = \&errorWrap;
$SIG{__DIE__}  = \&errorWrap;

# Usage information global variable.
$PROTOSCAN::usage = <<EOF;

Usage: protoscan [command] [options...]

Available commands: [scan, fetch]

Command: scan [options..]

    -proxy          Proxy to scan in IP:Port format.
    -proxy-file     Path to a file containing proxies in the IP:Port format.
                    (e.g. './example.txt')
    -http           Enable HTTP protocol scanning probe.
    -https          Enable HTTPS protocol scanning probe.
    -socks4         Enable SOCKS4 protocol scanning probe.
    -socks5         Enable SOCKS5 protocol scanning probe.
    -all            Enable all protocol scanning probes.
    -timeout        Second(s) to wait before abandoning request (e.g. '10')
    -retries        Count of attempts made before giving up on the request (e.g. '2')
    -threads        Number of worker threads (e.g. '5')
    -output-file    Output file path (e.g. './example.txt')

Command: fetch [options..]

    -url            URL leading to a webpage housing proxy servers.
    -url-file       Path to a file containing URLs (e.g. './example.txt')
    -timeout        Second(s) to wait before abandoning request (e.g. '10')
    -threads        Number of worker threads (e.g. '5')
    -output-file    Output file path (e.g. './example.txt')
EOF

getCommand($ARGV[0]);