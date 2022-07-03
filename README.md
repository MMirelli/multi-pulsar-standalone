# Multi pulsar standalone manager

This tool is meant to be provide a library / CLI utility capable to manage many local pulsar standalone deployments.

## Requirements

* `bash` > 5.1.x
* `yq` > 4.16.x
* GNU `sed`

## Usage 

Download and untar a pulsar version and move to the pulsar home directory. 

For example:

```
cd /tmp/
wget https://www.apache.org/dyn/mirrors/mirrors.cgi?action=download&filename=pulsar/pulsar-2.10.0/apache-pulsar-2.10.0-bin.tar.gz
tar -xf apache-pulsar-2.10.0-bin.tar.gz
cd apache-pulsar-2.10.0
```

In this case `/tmp/apache-pulsar-2.10.0` is the pulsar home directory.

### As a library

0. create a bash script (`script.sh`) in your pulsar home
1. source `lib.sh` in `script.sh`
2. change `multi-standalone-config.yaml` based on your needs and move it to the pulsar home
3. use the functions in `lib.sh`

### As a CLI utility

Simply run the desired utility as a bash script.
