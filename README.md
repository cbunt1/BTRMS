Buntster's Tomato-Router-Configuration-Tool
A tool to clone, backup, restore, modify and manipulate the configuration of routers running Tomato firmware

Buntster's Tomato Router Tool

A simple shell script to allow the backup and/or modification of the config on 	a Shibby Tomato router. The primary difference between this script and most other setups I've seen is that this creates a complete soup-to-nuts restoration script and process. 

The final output is a one-step erase and re-write of your router's configuration. In other words, archive the output files, and when things crash (or like me, you over-tweak something) you can just load a saved script, kick it off, and go have a cup of coffee while it	rebuilds itself. 
	
I have even successfully configured a freshly flashed router remotely as a proof of concept. It wasn't the original idea, but if you've ever started	tinkering (which I suspect you have if you're even trying to use this	script) you know how the "I wonder if..." bug can bite. 

This script was originally written with the idea of transferring the test and	production configurations back and forth in my home office network. I grew tired of not being able to transfer the settings between functionally identical routers, and I just knew I would miss a setting if I kept at it.
	
So I took a bunch of hints from the original "settings.sh" script I found on shibby's site and considered everything I wanted to be able to do between the five Tomato machines in my network, some running VPN's to each other, some serving as wireless repeaters, and some serving as wireless bridges.
	
It evolved from there and while I find it useful, you may find it to be	bloatware. That's OK, I don't deny it. I broke the KISS rule, but it's been	a hell of a fun ride, and somewhere in the process I remembered a little bit about how (not) to program. I also was reminded that I think of coding as a necessary evil (LOL).
	
It's only been tested on Shibby builds, and only on Asus RT-66AU models, but I think it will work on others as well. I will soon try it on an older WRT-54GS as soon as I slow down long enough to put Tomato on it.
	
As I worked thorugh this, I realized my primary goal was consistency rather	than perfection -- I wanted to be able to load the core configurations of my environment and get everything close enough that I can final-tweak in a few minutes rather than a few hours.
	
So, here it is in all its glory. Yours for the taking, and I hope it works well	for you. I'm putting it out there free. That's free as in beer, free as in speech. If you use it commercially, well, good for you. I might do the same someday, but haven't gotten around to it. If you make money from it,	that's cool too. 
	
You can contact me via email at cbunt1@yahoo.com.

--Chris Bunt
Houston, TX  USA
