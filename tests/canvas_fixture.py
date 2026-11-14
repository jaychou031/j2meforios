"""Generate our own tiny regression MIDlet, without a JDK or third-party game."""
import struct
from zipfile import ZipFile, ZIP_DEFLATED

def u2(n): return struct.pack('>H', n)
def u4(n): return struct.pack('>I', n)

class Class:
    def __init__(self, name, parent, interfaces=(), flags=0x21):
        self.pool=[]; self.cache={}; self.methods=[]
        self.name=self.cls(name); self.parent=self.cls(parent)
        self.interfaces=[self.cls(i) for i in interfaces]; self.flags=flags
    def entry(self, key, data):
        if key not in self.cache:
            self.pool.append(data); self.cache[key]=len(self.pool)
        return self.cache[key]
    def utf(self, text):
        b=text.encode('utf-8'); return self.entry(('utf',text),b'\x01'+u2(len(b))+b)
    def cls(self, text): return self.entry(('class',text),b'\x07'+u2(self.utf(text)))
    def string(self, text): return self.entry(('str',text),b'\x08'+u2(self.utf(text)))
    def ref(self, kind, owner, name, desc):
        c=self.cls(owner)
        nt=self.entry(('nt',name,desc),b'\x0c'+u2(self.utf(name))+u2(self.utf(desc)))
        return self.entry((kind,owner,name,desc),bytes([kind])+u2(c)+u2(nt))
    def call(self, op, owner, name, desc):
        kind=11 if op==0xb9 else 10
        return bytes([op])+u2(self.ref(kind,owner,name,desc))+(b'\x02\x00' if op==0xb9 else b'')
    def method(self,name,desc,code=None,flags=1,locals=2,stack=8):
        n,d=self.utf(name),self.utf(desc)
        if code is None: attrs=b'\x00\x00'
        else:
            data=u2(stack)+u2(locals)+u4(len(code))+code+u2(0)+u2(0)
            attrs=u2(1)+u2(self.utf('Code'))+u4(len(data))+data
        self.methods.append(u2(flags)+u2(n)+u2(d)+attrs)
    def output(self):
        return (b'\xca\xfe\xba\xbe'+u2(0)+u2(49)+u2(len(self.pool)+1)+b''.join(self.pool)+
                u2(self.flags)+u2(self.name)+u2(self.parent)+u2(len(self.interfaces))+
                b''.join(u2(i) for i in self.interfaces)+u2(0)+u2(len(self.methods))+
                b''.join(self.methods)+u2(0))

def create(path):
    canvas='javax/microedition/lcdui/Canvas'
    full='com/nokia/mid/ui/FullCanvas'
    midlet='javax/microedition/midlet/MIDlet'
    signatures=[('getGameAction','(I)I'),('getKeyCode','(I)I'),('getKeyName','(I)Ljava/lang/String;')]
    interface=Class('KeyQueries','java/lang/Object',flags=0x601)
    for n,d in signatures: interface.method(n,d,flags=0x401)
    concrete=Class('KeyCanvas',full,['KeyQueries'])
    concrete.method('<init>','()V',b'\x2a'+concrete.call(0xb7,full,'<init>','()V')+b'\xb1')
    concrete.method('paint','(Ljavax/microedition/lcdui/Graphics;)V',b'\xb1')
    main=Class('InputProbe',midlet)
    main.method('<init>','()V',b'\x2a'+main.call(0xb7,midlet,'<init>','()V')+b'\xb1')
    code=b'\xbb'+u2(main.cls('KeyCanvas'))+b'\x59'+main.call(0xb7,'KeyCanvas','<init>','()V')+b'\x4c'
    code+=b'\x2a'+main.call(0xb8,'javax/microedition/lcdui/Display','getDisplay','(Ljavax/microedition/midlet/MIDlet;)Ljavax/microedition/lcdui/Display;')
    code+=b'\x2b'+main.call(0xb6,'javax/microedition/lcdui/Display','setCurrent','(Ljavax/microedition/lcdui/Displayable;)V')
    for mode,op,owner in [('IFACE',0xb9,'KeyQueries'),('VIRTUAL',0xb6,canvas),('STATIC',0xb8,canvas)]:
        for name,desc in signatures:
            # Print a stable label and result. getKeyName(-1) is compared with
            # the existing static entry so its spelling need not be assumed.
            label=f'{mode}_{name}='
            code+=b'\xb2'+u2(main.ref(9,'java/lang/System','out','Ljava/io/PrintStream;'))
            code+=b'\x13'+u2(main.string(label))+main.call(0xb6,'java/io/PrintStream','print','(Ljava/lang/String;)V')
            code+=b'\xb2'+u2(main.ref(9,'java/lang/System','out','Ljava/io/PrintStream;'))
            if op!=0xb8: code+=b'\x2b'
            code+=b'\x04' if name=='getKeyCode' else b'\x02'  # UP action=1, key=-1
            code+=main.call(op,owner,name,desc)
            if name=='getKeyName':
                code+=b'\x02'+main.call(0xb8,canvas,name,desc)+main.call(0xb6,'java/lang/String','equals','(Ljava/lang/Object;)Z')
            code+=main.call(0xb6,'java/io/PrintStream','println','(I)V')
    code+=b'\xb1'
    main.method('startApp','()V',code)
    main.method('pauseApp','()V',b'\xb1')
    main.method('destroyApp','(Z)V',b'\xb1')
    with ZipFile(path,'w',ZIP_DEFLATED) as z:
        z.writestr('META-INF/MANIFEST.MF','Manifest-Version: 1.0\nMIDlet-Name: InputProbe\nMIDlet-Version: 1.0\nMIDlet-Vendor: Local tests\nMIDlet-1: InputProbe,,InputProbe\nMicroEdition-Configuration: CLDC-1.1\nMicroEdition-Profile: MIDP-2.0\n\n')
        for name,obj in [('KeyQueries',interface),('KeyCanvas',concrete),('InputProbe',main)]: z.writestr(name+'.class',obj.output())
