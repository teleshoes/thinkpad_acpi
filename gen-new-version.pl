#!/usr/bin/perl
use strict;
use warnings;

sub run(@);

my $LINUX_GIT_REPO = "$ENV{HOME}/Code/linux";
my $THINKPAD_ACPI_C = "$LINUX_GIT_REPO/drivers/platform/x86/thinkpad_acpi.c";

sub main(@){
  die "Usage: $0 OLD_VERSION NEW_VERSION\n" if @_ != 2;
  my ($oldVersion, $newVersion) = @_;
  die "invalid old version: $oldVersion\n" if $oldVersion !~ /^\d+(\.\d+)*$/;
  die "invalid new version: $newVersion\n" if $newVersion !~ /^\d+(\.\d+)*$/;
  if(not -d $oldVersion){
    die "missing $oldVersion\n";
  }elsif(-d $newVersion){
    die "$newVersion already exists\n";
  }

  my $gitBranch = `cd $LINUX_GIT_REPO ; git show -s --pretty=%d HEAD`;
  if($gitBranch !~ /\bv$newVersion\b/){
    die "ERROR: linux git repo HEAD is not v$newVersion\n";
  }
  if(not -f $THINKPAD_ACPI_C){
    die "ERROR: \"$THINKPAD_ACPI_C\" file not found\n";
  }

  run "mkdir", "$newVersion";

  run "cp", "$oldVersion/thinkpad_acpi.c", "$newVersion/old.c";
  run "cp", "$oldVersion/led.patch", "$newVersion/old.patch";

  run "cp", $THINKPAD_ACPI_C, "$newVersion/kernel.c";

  run "cp", "$newVersion/old.c", "$newVersion/old_patched.c";
  run "patch", "-p0", "$newVersion/old_patched.c", "$newVersion/old.patch";
  die "ERROR: cannot patch $oldVersion\n" if $? != 0;

  run "cp", "$newVersion/kernel.c", "$newVersion/kernel_patched.c";
  run "patch", "-p0", "$newVersion/kernel_patched.c", "$newVersion/old.patch";
  if($? != 0){
    print "\n\nWARNING: old patch failed\n";
  }else{
    run "rm", "-f", "kernel_patched.c.orig";
  }

  print "compare $newVersion/old_patched.c and $newVersion/kernel_patched.c\n";
  print "modify the file 'kernel_patched.c' to be correct, and then push enter to continue: ";
  <STDIN>;

  run "diff $newVersion/kernel.c $newVersion/kernel_patched.c > $newVersion/led.patch";
  run "cp $newVersion/kernel.c $newVersion/thinkpad_acpi.c";
}

sub run(@){
  print "@_\n";
  system @_;
}

&main(@ARGV);
