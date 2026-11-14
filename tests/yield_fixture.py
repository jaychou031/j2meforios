"""Our own yield-driven MIDlet; no JDK or redistributed game required."""
from zipfile import ZipFile, ZIP_DEFLATED
from canvas_fixture import Class, u2

def create(path):
    base='javax/microedition/midlet/MIDlet'
    app=Class('YieldProbe',base)
    canvas=Class('YieldCanvas','javax/microedition/lcdui/Canvas')
    canvas.method('<init>','()V',b'\x2a'+canvas.call(0xb7,'javax/microedition/lcdui/Canvas','<init>','()V')+b'\xb1')
    canvas.method('paint','(Ljavax/microedition/lcdui/Graphics;)V',b'\xb1')
    app.method('<init>','()V',b'\x2a'+app.call(0xb7,base,'<init>','()V')+b'\xb1')
    clock=app.call(0xb8,'java/lang/System','currentTimeMillis','()J')
    # Local 1/2 holds the initial long clock; all yields run on one Java
    # thread. The interpreter must resume after the native, not repeat it.
    code=b'\x2a'+app.call(0xb8,'javax/microedition/lcdui/Display','getDisplay','(Ljavax/microedition/midlet/MIDlet;)Ljavax/microedition/lcdui/Display;')
    code+=b'\xbb'+u2(app.cls('YieldCanvas'))+b'\x59'+app.call(0xb7,'YieldCanvas','<init>','()V')
    code+=app.call(0xb6,'javax/microedition/lcdui/Display','setCurrent','(Ljavax/microedition/lcdui/Displayable;)V')
    code+=clock+b'\x40'
    code+=app.call(0xb8,'java/lang/Thread','yield','()V')*96
    out=b'\xb2'+u2(app.ref(9,'java/lang/System','out','Ljava/io/PrintStream;'))
    code+=out+b'\x13'+u2(app.string('YIELD_ELAPSED_MS='))+app.call(0xb6,'java/io/PrintStream','print','(Ljava/lang/String;)V')
    code+=out+clock+b'\x1f\x65'+app.call(0xb6,'java/io/PrintStream','println','(J)V')
    code+=b'\x2a'+app.call(0xb6,base,'notifyDestroyed','()V')+b'\xb1'
    app.method('startApp','()V',code,locals=3)
    app.method('pauseApp','()V',b'\xb1')
    app.method('destroyApp','(Z)V',b'\xb1')
    with ZipFile(path,'w',ZIP_DEFLATED) as z:
        z.writestr('META-INF/MANIFEST.MF','Manifest-Version: 1.0\nMIDlet-Name: YieldProbe\nMIDlet-Version: 1.0\nMIDlet-Vendor: Local tests\nMIDlet-1: YieldProbe,,YieldProbe\nMicroEdition-Configuration: CLDC-1.1\nMicroEdition-Profile: MIDP-2.0\n\n')
        z.writestr('YieldProbe.class',app.output())
        z.writestr('YieldCanvas.class',canvas.output())
