TEST 1
TEST 2
TEST 3
TEST 4
TEST 5
TEST 6

# packer-io-test

This repo contains Packer templates that test I/O performance of VMs launched in Jetstream and AWS.
For info about the benchmarks used, see:
https://www.binarylane.com.au/support/solutions/articles/1000055889-how-to-benchmark-disk-i-o.

## Existing VMs

### Jetstream

Using the Horizon dashboard, I launched an instance in the IU Jetstream cloud with the following properties:

1. ID: 4ec8a221-6d44-4956-be20-636fda7dfa18  (still running, if you'd like to examine it)
1. Flavor Name: m1.medium
1. Image Name: JS-API-Featured-Ubuntu16-Oct-25-2017

I copied over `benchmark.sh` to the instance, logged in, and executed it with the command:
`./benchmark.sh | tee openstack-existing-vm.txt`. I then copied the output to the `benchmark-results/`
directory of this repository.

The most interesting lines from the results are:
```
  read : io=3071.7MB, bw=2593.1KB/s, iops=648, runt=1213030msec
  write: io=1024.4MB, bw=885460B/s, iops=216, runt=1213030msec
```

The benchmark seems to have a lot of variance. I ran it a couple days earlier and got:
```
  read : io=3071.7MB, bw=5417.2KB/s, iops=1354, runt=580638msec
  write: io=1024.4MB, bw=1806.5KB/s, iops=451, runt=580638msec
```

And another:
```
  read : io=3071.7MB, bw=2917.2KB/s, iops=729, runt=1077930msec
  write: io=1024.4MB, bw=996437B/s, iops=243, runt=1077930msec
```

### Amazon

Using the Amazon web UI, I launched an instance in the Amazon EC2 cloud with the following properties:

1. Instance type: t2.xlarge
1. AMI ID: ubuntu-xenial-16.04-amd64-server-20170721 (ami-cd0f5cb6)

I copied `benchmark.sh` to the instance, logged in, and executed it with the command:
`./benchmark.sh | tee amazon-existing-vm.txt`. I then copied the output to the `benchmark-results/`
directory of this repository.

The most interesting lines from the results are:
```
  read : io=3071.7MB, bw=9205.3KB/s, iops=2301, runt=341696msec
  write: io=1024.4MB, bw=3069.8KB/s, iops=767, runt=341696msec
```

There is NO variance in the AWS IOSP benchmarks: I ran it 4 times and always got exactly 2301/767. Remarkable!

## Packer

### Jetstream

I executed the following command on my laptop:

`packer build -color=false openstack.json | tee benchmark-results/openstack-packer-vm.txt`

The most interesting lines from the results are:
```
    openstack:   read : io=3071.7MB, bw=2778.1KB/s, iops=694, runt=1131865msec
    openstack:   write: io=1024.4MB, bw=948955B/s, iops=231, runt=1131865msec
```

And another:
```
    openstack:   read : io=3071.7MB, bw=2513.5KB/s, iops=628, runt=1251432msec
    openstack:   write: io=1024.4MB, bw=858288B/s, iops=209, runt=1251432msec
```

One more!
```
    openstack:   read : io=3071.7MB, bw=3784.6KB/s, iops=946, runt=831126msec
    openstack:   write: io=1024.4MB, bw=1262.5KB/s, iops=315, runt=831126msec
```
### Amazon

I executed the following command on my laptop:

`packer build -color=false amazon-ebs.json | tee benchmark-results/amazon-packer-vm.txt`

The most interesting lines from the results are:
```
    amazon-ebs:   read : io=3071.7MB, bw=9204.1KB/s, iops=2301, runt=341706msec
    amazon-ebs:   write: io=1024.4MB, bw=3069.7KB/s, iops=767, runt=341706msec
```

## Observations

The performance of Jetstream VMs is considerably less than similarly-sized Amazon VMs. Perhaps that's to be expected:
I realize that Amazon has vastly more resources to throw at the problem than Jetstream does.

The troubling issue is that performance seems to have declined sharply in the last week or so. Unfortunately,
I don't have hard numbers for the prior period. I can only point to an Ansible playbook that is taking dramatically
longer to finish than it used to, specifically, [this task](
https://github.com/cwardgar/ansible-nexus3-oss/blob/82013d3794b823d775a0078433d81529bc3b48f1/tasks/nexus_install.yml#L119).
At that point in the playbook, I've started a [Nexus Repository Manager (NXRM) 3](
https://www.sonatype.com/nexus-repository-oss) instance for the first time and am waiting for it to become available.
The initial startup creates several databases for application data, among other I/O-heavy tasks. Previously, it took
less than a minute to complete (it still does on AWS). Now it takes about 250 seconds on average, although it's also
timed out after 360 seconds a few times.

That brings me to the other big issue with Jetstream: variance. As the benchmarks show, I/O performance can vary
significantly between benchmark runs. I've experienced this in my playbook execution times as well. Is that variance
expected?

### Packer VMs versus existing VMs

Initially, I believed that newly-launched VMs (i.e. those created by Packer) exhibited poorer performance than
instances that had already been running for a while. Benchmarks haven't really borne that out, but we would need to
take many more samples to be sure.

### cloud-init

First, I'd like to thank you for cluing me into [cloud-init](http://cloudinit.readthedocs.io/en/latest/index.html).
I had no idea that even existed, but I plan to use it in my Packer and Terraform configs going forward.

In your email, you mentioned that vendor-data auto-update could be disabled with the following config:
```yaml
#cloud-config
# Upgrade the instance on first boot
# (ie run apt-get upgrade)
#
# Default: false
# Aliases: apt_upgrade
package_upgrade: false
```

That intrigued me because I've dealt with apt issues after boot in the past, particularly this one:
```
Could not get lock /var/lib/dpkg/lock - open (11: Resource temporarily unavailable)
Unable to lock the administration directory (/var/lib/dpkg/), is another process using it?
```

I assume that's related to `package_upgrade`? Thus far, my solution has been to simply wait for the upgrades to
finish (see `wait-for-system-updates.sh`), which can take several minutes.

Unfortunately, adding `"user_data_file": "user-data.yml"` to `openstack.json` seems to have no effect. On my most recent
run, I still spent 135 seconds in `wait-for-system-updates.sh`, waiting for `/var/lib/dpkg/lock` to become free.

Is Jetstream not honoring my `user-data.yml`? Or perhaps Packer is not properly communicating it? Do you know of a way
to check?
