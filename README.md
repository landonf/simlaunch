# Simulator Launcher

## Introduction ##

Simulator Launcher builds custom executables to automatically launch an
embedded iPhone Simulator application using the correct iPhone SDK.

To use, drag any iPhone Simulator binary onto the "Simulator Builder"
application. This will create a new Mac OS X application that bundles
and launches your iPhone Simulator application from within Mac OS X. The
new application's icon and name will be derived from your iPhone Simulator
application.

The built launcher will:

* Detect all installed iPhone SDKs (such as the beta iPad SDK) using Spotlight,
  even if they're in non-standard locations
* Automatically select the best available SDK for your application.
* Install and launch your application in the appropriate Simulator.
* Works with both iPhone and iPad simulator binaries.

Watch the screencast here: 
	[http://www.youtube.com/watch?v=Jnm4Zj36shU](http://www.youtube.com/watch?v=Jnm4Zj36shU)

## Building ##

The project should build and run on Mac OS X 10.6 and 10.7. To build, run the disk image target:

```
xcodebuild -configuration Release -target "Disk Image"
```

Binary releases of Simulator Launcher are also available from:

[http://github.com/landonf/simlaunch/downloads](http://github.com/landonf/simlaunch/downloads)

## Authors ##

* Landon Fuller
* Erica Sadun

The application's icon was graciously provided by Pete Zich.