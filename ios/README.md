# iOS platform

UIKit frontend, nj_port adapter and AudioQueue output for iOS 15.5.
The Java VM runs on one worker thread. UI events cross an ordered queue;
rendered frames cross a locked snapshot. See the repository README for build
instructions and the distinction between implemented and device-tested features.
