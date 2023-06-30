
Dirty PoC based on this https://www.crowdstrike.com/blog/falcon-complete-thwarts-vanguard-panda-tradecraft/

Backdoors tomcat-websocket.jar on host

 - Compile C.java and WsSci.java into classes  
 - Move them into a Jar  
 - Modify sourceURL with the path of hosted Jar 
 - Upload backdoor.jsp Trigger backdoor.jsp 
   
Backdoored version left in/tmp/stomped-tomcat-websocket.jar for testing however modify relocateAndStomp to overwrite lib/tomcat-websocket.jar
  
C.class will be triggered on Tomcat reload/restart

Tested on tomcat-8.5.90
