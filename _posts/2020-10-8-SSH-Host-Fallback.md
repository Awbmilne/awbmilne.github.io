---
title: "SSH Host Fallback"
date: 2020-10-08T22:45:00-04:00
categories:
  - Blog
tags:
  - SSH
  - Homelab
---


- [SSH config for Fallback Hostname?](#ssh-config-for-fallback-hostname)
  - [What? Why?](#what-why)
  - [Here is what I did](#here-is-what-i-did)
    - [First, How do we Identify the Server?](#first-how-do-we-identify-the-server)
    - [Using our Fancy new Script](#using-our-fancy-new-script)
  - [Getting the server fingerprint](#getting-the-server-fingerprint)
  - [Things Learned:](#things-learned)
  - [WOHOO!](#wohoo)
  - [Download](#download)
  - [Files](#files)
    - [Windows Script](#windows-script)
    - [Unix Script (Linux, Mac)](#unix-script-linux-mac)



# SSH config for Fallback Hostname?
## What? Why?
If you're anything like me, You enjoy messing with your raspberry pi or linux server at home.\
SSH is the most common and one of the most secure ways of accessing a terminal over a network.\
After messing around with SSH for awhile, most people discover and enjoy the SSH config file, but Ive always had a particular gripe with it...

**How do you use one SSH config Host entry for both local and remote access to a server?**

I like to run scripts and configure webhosts both when im at home and when im away, how do I have OpenSSH figure out the Hostname for me?

The `.ssh/config` file for OpenSSH does not directly support this functionally... But, there is a farely simple way to create the functionality. Basically, You just need a script to check for the servers existance.

I searched a long time for a good option for this, but was never satisfied with:\
`Match host mycomputer exec "nc -G 1 -z 192.168.1.11 %p"`\
`Match host mycomputer exec "ping 192.168.1.11"`\
and similair options.

My primary reason for not liking them being, while they do check for a listening server, They dont check for YOUR Server. So on work/school/coffee-shop networks, the same IP could act as a middleman or could just frustrate you endlessly.

So eventually, I got fed up with manually typing `ssh server-local` and `ssh server-global` for my two host configs, and I decided to make a script to automate this process.



## Here is what I did
### First, How do we Identify the Server?
To me, the best way to identify a server is with the data it already uses for identity:\
*The SSH Host keys*

So, If we can grab the SSH Host keys from the server, we can use those as nametags to check if the server that is listening is the correct server.

OpenSSH has a tool for this:\
`ssh-keyscan [host]`

Its a very simple, but effective tool. It gathers the SSH Keys without authenticating to the server. This is great!\
*But*, Those key values are really long, especially 2048 bit RSA keys...

So, Lets use `ssh-keygen -lf` to shorten those into fingerprints.

*Note: Credit for the* `ssh-keyscan` *and* `ssh-keygen` *combo*

Here is the script I wrote for gathering and verifying a server Fingerprint:

**~/.ssh/scripts/check_host_fingerprint.cmd`**
```
@echo off
 
REM GET UNIQUE TEMP FILE
:uniqLoop
set "temp_file=%tmp%\ssh_host_key_verification~%RANDOM%.tmp"
if exist "%temp_file%" goto :uniqLoop
 
REM SCAN HOST KEYS INTO TEMP FILE
ssh-keyscan %1 > %temp_file% 2>%1
 
REM CHECK IF ANY FINGERPRINTS MATCH PROVIDED
FOR /F "USEBACKQ tokens=2" %%G IN (`ssh-keygen -lf %temp_file%`) DO IF /I "%2"=="%%G" GOTO MATCH

:NOMATCH
    EXIT /b 2
    GOTO :EOF

:MATCH
    EXIT /b 0
    GOTO :EOF
```

Yeah, yeah... I know, *Windows* :dizzy_face:\
But dont fret, I made a Unix version too. Find it in the [files section](#download) below.



### Using our Fancy new Script
From Here, we get to use one of the more rare functions of the SSH config file...\
The `Match` tool

The `Match` Tool allows us to check for various conditions to apply settings for an SSH host

`Match` is kinda qwerky, but the best documentation ive found for it is [man7.org's ssh man page](https://man7.org/linux/man-pages/man5/ssh_config.5.html)

Lets see how it works in our config file:

**~/.ssh/config**
```
Host my_auto_host
    User username
    Match host "my_auto_host" exec "%d/.ssh/scripts/check-host-fingerprint.cmd 192.168.0.100 SHA256:12345678901234567890123456789012345678901234567"
        Hostname 192.168.0.100
        Port 22
    Hostname server.domain.org
    Port 1022
```

Now, this `Match` arguements seems like a long message... But all we are doing is calling our script which we stored in the `~/.ssh/scripts/` directory and passing the Address and Host-key fingerprint as arguements.\
*Note,* `%d` *expands to the local user's home directory when used in the config file.*

`Match` uses this script as a true-false for whether that server is available at that Address.

While this does add 2-3 seconds of waiting into the SSH process... It works pretty consistently, and doesnt suffer any security vulnerabilities (Since SSH is still doing proper authentication.)

*Note: SSH config only considers the first setting that matches for a Host, this means that if you have two* `Hostname`*'s defined in the same* `Host` *section, OpenSSH always uses the first one, same goes for the majority of the parameters.*

*Note: The* `Match` *Section functions much like the* `Host` *Section. Even if you nest it inside a* `Host` *section, OpenSSH tries to run it every time you use the* `ssh` *command. This is why we put* `host "[Hostname]"` *before the* `exec`*, this way it only runs the script when we try to connect to **that** server.*



## Getting the server fingerprint
The fastest way I have found to get the SSH server Keys is by running:
```
ssh [Hostname] -v
```

and looking for the line that looks like:
```
debug1: Server host key: ecdsa-sha2-nistp256 SHA256:12345678901234567890123456789012345678901234567
```

The `SHA256:12345678901234567890123456789012345678901234567` is the Fingerprint, the value you want.

*Note: there are far better ways to do this... But this is easy and cross platform. :thumbs_up:*



## Things Learned:

<details>
<summary> Expand if you want some extra commentary
</summary>

1. The `.ssh/config` `match` function is very lightly documented... so here is some info:
    - `host` uses some special regex to match hostnames from the command line, in this example,  I just use the same hostname as I want to have fallback for. BUT, you can easily imagine using this to check a range of hostnames as desired.
    - `exec` executes a command (I assume in the same terminal) and uses the output as true/false. You can also use `!exec` to, you guessed it, do the inverse.
    - You can use both `host` and `exec` in the same line in a sort of & functionality, You may be even be able to stack them as much as you like :metal:
    - The `Match` tool only trys until it gets a false (or all matches are true), so use the `host` first to keep from running the `exec` for every ssh call.

2. The ssh config file always uses the first available config value it reaches. 
    - This means you have to put the match statement above your normal variables:

    - This works:
        ```
        Host my_server
            Match host "Server" exec "[Command]"
                Hostname 192.168.0.100
                Port 22
            Hostname server.domain.org
            Port 1022
        ```
    - This doesnt:
        ```
        Host my_server
            Hostname server.domain.org
            Port 1022
            Match host "Server" exec "[Command]"
                Hostname 192.168.0.100
                Port 22
        
        ```
    - You can use this to your advantage, but keep it in mind

3. Another way to do this is by creating a script that trys to connect over SSH instead of checking fingerprints. This serves the same functionality, but it means you login 2 times quickly to your server... I have SSH login notifications setup with pushover, so I dont want double notifications.
4. If your SSH server uses a non-standard port, your will have to add a `Port` arguement to the scripts below. `ssh-keyscan` takes a `-p` port arguement, So just add that into the Script.

</details>



## WOHOO!
Give it a try!

If it doesnt work, Let me know!\
Shoot me a Tweet, and Email,

Have suggestions on how to improve this post?\
Make a Pull request on the [Github Pages repo](https://github.com/Awbmilne/awbmilne.github.io).



## Download
- Windows Script
  - [check-host-fingerprint.cmd](/assets/scripts/SSH-Host-Fallback/Windows/check-host-fingerprint.cmd)
  - [Example SSH config](/assets/scripts/SSH-Host-Fallback/Windows/config)
- Unix Script (Linux, Mac)
  - [check-host-fingerprint.sh](/assets/scripts/SSH-Host-Fallback/Linux/check-host-fingerprint.sh)
  - [Example SSH config](/assets/scripts/SSH-Host-Fallback/Linux/config)
  

  
## Files
### Windows Script
<details>
<summary> **check-host-fingerprint.cmd**
</summary>
```
REM @echo off

REM GET UNIQUE TEMP FILE
:uniqLoop
set "temp_file=%tmp%\ssh_host_key_verification~%RANDOM%.tmp"
if exist "%temp_file%" goto :uniqLoop

REM SCAN HOST KEYS INTO TEMP FILE
ssh-keyscan %1 > %temp_file% 2>%1

REM CHECK IF ANY FINGERPRINTS MATCH PROVIDED
FOR /F "USEBACKQ tokens=2" %%G IN (`ssh-keygen -lf %temp_file%`) DO IF /I "%2"=="%%G" GOTO MATCH

:NOMATCH
    EXIT /b 2
    GOTO :EOF

:MATCH
    EXIT /b 0
    GOTO :EOF
```
</details>

<details>
<summary> **config**
</summary>
```
# Host with Global Fallback
Host my_auto_host
    User username
    Match host "my_auto_host" exec "%d/.ssh/scripts/check-host-fingerprint.cmd 192.168.0.100 SHA256:12345678901234567890123456789012345678901234567"
        Hostname 192.168.0.100
        Port 22
    Hostname server.domain.org
    Port 1022

# Secondary Host using Primary as Proxy
Host secondary
    User u5ernam3
    Hostname 192.168.0.101
    Port 22
    ProxyJump my_auto_host
```
</details>

### Unix Script (Linux, Mac)

<details>
<summary> **check-host-fingerprint.sh**
</summary>
```
#!/bin/bash

fingerprints=$(ssh-keygen -lf <(ssh-keyscan $1 2>/dev/null))

for fingerprint in $fingerprints
do
        if [ "$fingerprint" == "$2" ]
        then
                exit 0
        fi
done

exit 1
```
</details>

<details>
<summary> **config**
</summary>
```
# Host with Global Fallback
Host my_auto_host
    User username
    Match host "my_auto_host" exec "/bin/bash %d/.ssh/scripts/check-host-fingerprint.sh 192.168.0.100 SHA256:12345678901234567890123456789012345678901234567"
        Hostname 192.168.0.100
        Port 22
    Hostname server.domain.org
    Port 1022

# Secondary Host using Primary as Proxy
Host secondary
    User u5ernam3
    Hostname 192.168.0.101
    Port 22
    ProxyJump my_auto_host
```
</details>
