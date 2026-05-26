## Emails from John Siegenthaler

---------- Forwarded message ---------
From: john siegenthaler <siggy0269@gmail.com>
Date: Mon, May 25, 2026 at 4:12 PM
Subject: non-pressure tank - another variation
To: George Baker <gbaker@gridworks-consulting.com>, Jessica Millar <jmillar@gridworks-consulting.com>
George & Jessica,

One concern with any of these storage systems is either a retrofit or new construction to a building with low temperature emitters, such as floor heating.

There should be a means of reducing the water temperature from storage to these types of heat emitters.

There are several  ways to do this using either valves or variable speed circulators.

One option I was hoping for was the use of a Grundfos UPMS 20-78 circulator with 0-10 VDC or PWM speed control (same as you are using now) that would 
regulate the flow through the water side of the brazed plate heat exchanger in response to achieving and maintaining a target supply temperature to the 
heat emitters.  The “problem” - as far as I can determine - is that Grundfos only offers this circulator with a cast iron volute.  We need to use either 
stainless steel or a high temperature polymer volute to be compatible with an “open” loop storage system (e.g., to prevent corrosion of the circulator).

Another option is to use a modulating valve that controls mixing of hot water from storage with cooler water on return side of the heat emitters.  The 
attached schematic shows one possibility.  The 2-way modulating valve within the orange “cloud” on the attached  drawing could be used for two purposes:

    To bypass flow during heat pump defrost with all zones off.  The thermal mass of the domestic preheat tank provides the heat needed for defrost.  Using 
the tank for the defrost heat eliminates need to send chilled water through one or the zone circuits, and eliminates need for a volumizer tank.

2. During times other than defrost this valve could regulate the flow of cool water into the tee below the distribution system, where it would mix with hot 
water from storage.  The resulting mixed temperature would be read from a sensor downstream of the distribution circulator and the valve would be 
controlled to achieve a target supply temperature suing a PID loop.  Valve is motored fully open at beginning of heat call involving storage, and slowly 
closes to allow less cool water into mixing tee as storage cools down.  The target supply temperature could be either a setpoint or based on outdoor reset.

This valve would eliminate the need for a speed controlled circulator for (Phot).  The net cost of this valve would only be the difference between a 
modulating valve and a zone valve (since the latter would be needed if the only function was defrost bypass). About $85 more based on Caleffi 1” valves. I 
likely would be the same valve at shown for (MV1) in the schematic.

I did find some basic stainless steel circulators from Grundfos that would work for (Phot) and (Pcool).  They cost about $345.  Definitely more than cast 
iron but quite a bit less than some others at $450-550.

John
