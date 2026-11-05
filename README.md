# Protoscan

A Perl command-line tool for fetching proxy candidates and checking HTTP, HTTPS, SOCKS4, and SOCKS5 support.

## Get started

Requires Perl with thread support and the modules imported by [protoscan.pl](protoscan.pl), including LWP::UserAgent, Geo::IP, HTTP::Status, NetAddr::IP::Util, and Data::Validate::URI. The original target was Windows; other platforms may need adjustments.

Scan the included sample list:

```sh
perl protoscan.pl scan -proxy-file ./proxies-sample.txt -all -threads 10 -output-file ./results.csv
```

Fetch candidates from a list of source URLs:

```sh
perl protoscan.pl fetch -url-file ./urls-sample.txt -output-file ./fetched.txt -threads 8
```

## Contents

- [protoscan.pl](protoscan.pl): scan and fetch commands.
- [Sample proxies](proxies-sample.txt) and [source URLs](urls-sample.txt).
- [Object-oriented variant](oop-version/README.md).
- `maxmind4.dat`: legacy country-lookup data; freshness depends on the supplied database.

[Command reference](docs/commands.md) · [Apache 2.0 license](LICENSE)
