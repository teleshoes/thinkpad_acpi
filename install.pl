#!/usr/bin/perl
use strict;
use warnings;

sub install($);

my $mod = "thinkpad_acpi.ko";
my $modprobeConfFile = "/etc/modprobe.d/thinkpad_acpi.conf";
my $modprobeOpts = "options thinkpad_acpi fan_control=1\n";

sub main(@){
  my $kernel = `uname -r`;
  chomp $kernel;

  my ($major, $minor) = ($1, $2) if $kernel =~ /^(\d+)\.(\d+)/;
  my $srcDir;
  if($major < 3 or $minor < 3){
    $srcDir = '3.2';
  }elsif($minor < 8){
    $srcDir = '3.3';
  }elsif($minor < 10){
    $srcDir = '3.8';
  }else{
    $srcDir = '3.10';
  }

  print "installing version in $srcDir/\n";
  chdir "$srcDir";
  $ENV{PWD} = "$ENV{PWD}/$srcDir";

  my $dir = "/lib/modules/$kernel/kernel/drivers/platform/x86/";

  system "patch thinkpad_acpi.c led.patch";
  system "make";
  system "patch -R thinkpad_acpi.c led.patch";

  install $dir if -e $mod;

  print "Cleaning..\n";
  system "make clean";
}

sub install($){
  my $dir = shift;
  print "\n\nsuccess!\n";
  my $now = `date +%s`;
  chomp $now;
  my $bak = "$mod.orig.$now";
  print "copying $mod to $dir\nbackup in $bak\n";
  system "sudo mv $dir/$mod $dir/$bak";
  system "sudo cp $mod $dir";

  print "\n\n";
  print "replacing $modprobeConfFile:\n";
  system "cat", $modprobeConfFile;
  print "with:\n";
  open FH, "| sudo tee $modprobeConfFile";
  print FH $modprobeOpts;
  close FH;
  print "\n\n";

  print "remove and add module thinkpad_acpi\n";
  system "sudo modprobe -r thinkpad_acpi";
  system "sudo modprobe thinkpad_acpi";
}

&main(@ARGV);
