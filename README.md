# Proxter
Multithreaded proxy testing script that supports HTTP/HTTPS & SOCKS4/5 proxies. 

## Usage

    usage: proxter.pl [-45?ghijoprst] [long options...]
    --help (or -?)         Prints this usage information.
                           aka --usage, -h
    --input STR (or -i)    Path to input proxy file
    --output STR (or -o)   Path to output proxy file
    --json (or -j)         Enable export in JSON format
    --http (or -p)         Enable HTTP probe
    --https (or -s)        Enable HTTPS probe
    --socks4 (or -4)       Enable SOCKS4 probe
    --socks5 (or -5)       Enable SOCKS5 probe
    --threads INT (or -t)  Number of worker threads to be used
    --giveup INT (or -g)   Request giveup timeout per host in seconds
    --retries INT (or -r)  Number of request retries per host

