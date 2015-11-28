###Buntster’s Tomato Router Maintenance System (BTRMS)###
*Copyright © 2014, 2015 Chris A. Bunt*

*All Rights Reserved*

*Licensed under the MIT license. See "LICENSE" for details.*


**What is the BTRMS?**

The BTRMS started out as a relatively simple shell script to backup and restore the configuration of my Asus RT-AC66U routers. 
The primary goal was to allow me to introduce a “hot-swap” spare into the environment so I could safely play with modifications and
configuration without risking my working production environment. It evolved into a tool that allows me to backup and restore
configurations, and even make modifications to an offline script.

**What does the BTRMS do?**

The main function of BTRMS is to create and manipulate scripted backups of Tomato-based router’s configurations. These backups made 
by the BTRMS are generated as shell script programs, allowing for some “on-the-fly” manipulation of specific parameters.

**How does it work?**

The core operation is relatively straightforward: it does an “nvram export” of the router’s running configuration. It then strips 
some hardware-specific and otherwise troublesome parameters that prevent you from copying the configuration between units using 
the traditional backup tools. It then generates a restoration script that can be executed later on the same or a different router.

**What’s special about BTRMS? Can’t I do the same thing with the onboard tools?**

If you are only working with a single router with a single version of firmware, then the onboard nvram backup tool is ideal. 
In fact, the onboard tools are more than adequate for most environments. For me, the limitation of the onboard tool is that it can 
only restore to the exact same router. Where BTRMS shines is in the ability to move or copy configurations between different hardware
units. You can also make modifications to the configuration, such as changing hostnames, DHCP ranges or subnets before restoring it,
making the scripting of a rollout project much more consistent.

**Won’t that break something?**

It sure could! Keeping configurations machine-specific and release-specific has significant advantages, especially for the individual
with one network, one router, and who only makes occasional changes to the configuration. At this point, I can’t be sure what (if any)
superfluous parameters we’re transferring between machines, and whether various releases will use parameters in the same ways or not.
All I can say is that it has worked for me, and saved me a lot of time in my multi-router, multi-location environment. It beats
building each similar configuration from scratch, hoping I didn’t forget a setting.

**Who is the target audience for this tool?**

If you flash your router’s firmware once or twice, and change your configuration once a year, the BTRMS is probably like swatting at
mosquitoes with a sledgehammer. If you live in the world of the “30/30/30 reset” and the phrase “It was working fine until….” is a
legitimate part of your vocabulary, then this is one more wrench in your toolbox. If you support multiple remote installations, setup
and maintain complex networks, or just like to see how far you can push a consumer-grade piece of hardware, the BTRMS is worth a look.

**Why did you build it?**

The Tomato firmware has a firmware configuration backup tool that works wonderfully, but has a limitation, which makes it difficult to
use in my environment: It is individually hardware specific. This makes it impossible to directly copy my configuration from one
(otherwise) identical router to another. The BTRMS removes this hardware-specific limitation and allows me to duplicate configurations
between multiple (identical) routers.

It also allows me to make minor “on the fly” modifications to an otherwise identical device. By so doing, I have been able to build a
base configuration setting up VPNs, QoS specifications, etc., and by changing the site-specific details such as hostname and WAN
interface configurations, propagate a configuration base throughout my environment.

**How do I use it?**

In a nutshell: download the latest release from https://github.com/cbunt1/BTRMS/releases/latest. Copy it to your router, unpack it,
and run the main script (./transfersettings.sh). Invoke it as “./transfersettings export” to export your configuration into a 
dated & version identified file. The output will go into a directory with the same name as your router’s hostname. For more detailed
usage information, see the instructions.txt file.

For a more automated backup methodology, suitable for a distributed environment, see the TR-AMS (Tomato Router-Automated Maintenance
System) at https://github.com/cbunt1/TR-AMS. 

**What are the requirements?**

This is a command-line tool, so you’ll need to have (or setup) ssh, or at minimum telnet access to the router(s) you wish to
manipulate.

A working shell environment, access to the router, and the ability to copy a file to it are sufficient for basic backup and restore
functions.

The tool has only been tested on Asus RT-66AU hardware running Shibby’s Tomato builds thus far. I don’t know whether it will run on
other Tomato-based environments, or even other Shibby builds for that matter. 

**Credits**

The original script was Shibby’s settings.sh script published on his site (http://tomato.groov.pl/) and I claim no originality. I even
admit to shamelessly overcomplicating his script. 

You can contact me via email at cbunt1@yahoo.com.
--Chris Bunt Houston, TX USA


