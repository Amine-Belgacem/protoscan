# Protoscan

Protoscan helps you collect proxy candidates and determine which protocols their endpoints actually support. Its Perl command-line interface can fetch addresses from source URLs, scan individual proxies or files, and export results for later review.

HTTP, HTTPS, SOCKS4, and SOCKS5 checks, latency measurements, and multithreaded processing make it useful for sorting an existing proxy list or preparing candidates for another networking workflow. The included samples show the expected input formats, and the object-oriented variant offers a separate implementation to study. Platform compatibility and country-lookup accuracy depend on the original implementation and supplied GeoIP data.

## What it does

- Scans proxy endpoints in IP:Port format
- Detects support for HTTP, HTTPS, SOCKS4, and SOCKS5
- Tests reachability and latency for each proxy
- Fetches proxy addresses from web pages or URL lists
- Exports results to CSV-style output for later use
- Supports multithreaded processing for better performance

## Project structure

- [protoscan.pl](protoscan.pl): main Perl script with scan/fetch commands
- proxies-sample.txt: sample proxy list
- urls-sample.txt: sample URL list
- [oop-version](oop-version): object-oriented variant of the project
- maxmind4.dat: GeoIP database used for country lookup
- LICENSE: project license

## Requirements

Requires Perl with thread support and the modules imported by [protoscan.pl](protoscan.pl), including LWP::UserAgent, Geo::IP, HTTP::Status, NetAddr::IP::Util, and Data::Validate::URI. The original target was Windows; other platforms may need adjustments.

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

This project is distributed under the Apache 2.0 license included in the repository.
