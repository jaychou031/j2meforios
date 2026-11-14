#include "../ios/PcmCapture.hpp"
#include <cassert>
#include <fstream>
#include <iterator>
#include <string>
#include <vector>
#include <cstdio>
int main(int argc,char **argv) {
    assert(argc==2); std::string path=std::string(argv[1])+"/capture-test.wav";
    audio::PcmCapture c; int16_t input[]={-32768,-100,100,32767};
    c.open(8000,2); c.append(input,2); assert(c.frames()==0 && !c.save(path.c_str()));
    c.enable(true); c.open(8000,2); c.append(input,2); assert(c.save(path.c_str()));
    std::ifstream f(path,std::ios::binary); std::vector<unsigned char> bytes((std::istreambuf_iterator<char>(f)),{}); f.close();
    assert(bytes.size()==52 && bytes[0]=='R' && bytes[22]==2);
    assert(bytes[44]==0 && bytes[45]==128 && bytes[50]==255 && bytes[51]==127);
    c.open(8000,1); assert(c.frames()==0);
    std::vector<int16_t> large(8000*31,123); c.append(large.data(),static_cast<int>(large.size()));
    assert(c.frames()==8000*30); c.append(input,1); assert(c.frames()==8000*30);
    std::remove(path.c_str()); std::puts("PCM capture: opt-in, exact WAV bytes, stream reset and 30-second bound passed.");
}
