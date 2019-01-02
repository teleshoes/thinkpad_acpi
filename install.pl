#!/usr/bin/perl
use strict;
use warnings;

sub createMakefile($);
sub install($);
sub version($);
sub selectSrcDir($);

my $mod = "thinkpad_acpi.ko";
my $modprobeConfFile = "/etc/modprobe.d/thinkpad_acpi.conf";
my $modprobeOpts = "options thinkpad_acpi fan_control=1\n";

my @kernels = `ls /lib/modules | sort -rV`;
my $availKernels = join "      ", @kernels;

my $usage = "Usage:
  $0 [KERNEL]
    KERNEL is a subdir of /lib/modules {default is `uname -r`}
    available:
      " . join("      ", @kernels) . "
";

sub main(@){
  die $usage if @_ > 1 or (@_ == 1 and $_[0] =~ /^(-h|--help)$/);
  my $kernel = shift;

  my $curKernel = `uname -r`;
  chomp $curKernel;

  $kernel = $curKernel if not defined $kernel;

  if(not defined version $kernel){
    die "Could not parse MAJOR.MINOR version of kernel '$kernel'\n\n$usage";
  }

  my $buildDir = "/lib/modules/$kernel/build";
  my $modDir = "/lib/modules/$kernel/kernel/drivers/platform/x86/";
  my $srcDir = selectSrcDir $kernel;

  die "unknown kernel/arch: $kernel\n" if not -d $modDir;
  die "missing src dir\n" if not defined $srcDir or not -d $srcDir;

  print "installing version in $srcDir/\n";
  chdir $srcDir;
  $ENV{PWD} = "$ENV{PWD}/$srcDir";

  createMakefile $buildDir;

  my @patches = glob "*.patch";

  for my $patch(@patches){
    system "patch thinkpad_acpi.c $patch";
  }
  system "make";
  for my $patch(reverse @patches){
    system "patch -R thinkpad_acpi.c $patch";
  }

  install $modDir if -e $mod;

  print "Cleaning..\n";
  system "make clean";
  system "rm Makefile";
}

sub createMakefile($){
  my $buildDir = shift;
  my $cwd = $ENV{PWD};

  my $makefileContent = ''
    .  "obj-m += thinkpad_acpi.o\n"
    .  "\n"
    .  "all:\n"
    .  "\tmake -C $buildDir M=$cwd modules\n"
    .  "\n"
    .  "clean:\n"
    .  "\tmake -C $buildDir M=$cwd clean\n"
    ;

  open FH, "> Makefile";
  print FH $makefileContent;
  close FH;
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

sub version($){
  my $s = shift;
  my $minorOffset = 100000;
  if($s =~ /^(\d+)\.(\d+)/){
    my ($maj, $min) = ($1, $2);
    return $maj * $minorOffset + $min;
  }else{
    return undef;
  }
}

sub selectSrcDir($){
  my $kernel = shift;
  my $kv = version $kernel;

  my @dirs = `ls`;
  chomp foreach @dirs;
  my %vs = map {version($_) => $_} grep {-d $_ and /^\d+\.\d+$/} @dirs;

  my $prev;
  for my $v(sort keys %vs){
    my $dir = $vs{$v};
    if($v > $kv){
      return defined $prev ? $prev : $dir;
    }
    $prev = $dir;
  }
  return $prev;
}

&main(@ARGV);
