# Protoscan

Protoscan is a Perl-based command-line utility for discovering and validating proxy servers. It can scan a list of proxies to determine whether they support HTTP, HTTPS, SOCKS4, or SOCKS5, and it can also fetch proxy candidates from URLs and export them to a file.

## What it does

- Scans proxy endpoints in IP:Port format
- Detects support for HTTP, HTTPS, SOCKS4, and SOCKS5
- Tests reachability and latency for each proxy
- Fetches proxy addresses from web pages or URL lists
- Exports results to CSV-style output for later use
- Supports multithreaded processing for better performance

## Project structure

- protoscan.pl: main Perl script with scan/fetch commands
- proxies-sample.txt: sample proxy list
- urls-sample.txt: sample URL list
- OOP-version/: object-oriented variant of the project
- maxmind4.dat: GeoIP database used for country lookup
- LICENSE: project license

## Requirements

This project requires Perl and a few Perl modules installed, including:

- IO::Socket::INET
- threads
- Thread::Queue
- LWP::UserAgent
- Geo::IP
- Data::Validate::URI

If you are missing modules, install them with CPAN or your system package manager.

## Usage

### Scan proxies

Scan a single proxy:

```bash
perl protoscan.pl scan -proxy 1.2.3.4:8080 -http -https -socks4 -socks5
```

Scan a file of proxies:

```bash
perl protoscan.pl scan -proxy-file ./proxies-sample.txt -all -threads 10 -output-file ./results.csv
```

### Fetch proxies from URLs

Fetch proxies from one URL:

```bash
perl protoscan.pl fetch -url https://example.com/proxy-list -output-file ./fetched.txt -threads 5
```

Fetch proxies from a URL file:

```bash
perl protoscan.pl fetch -url-file ./urls-sample.txt -output-file ./fetched.txt -threads 8
```

## Sample files

- proxies-sample.txt contains example proxy entries
- urls-sample.txt contains example source URLs

## Notes

- The script was originally developed for Windows and Linux/macOS may require small adjustments.
- The GeoIP database file is not always up to date; update it manually if needed.
- This tool is intended for lawful, authorized use only.

## License

This project is distributed under the GPL-style license included in the repository.
