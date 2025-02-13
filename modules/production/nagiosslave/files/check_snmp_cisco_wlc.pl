#!/usr/bin/perl
# Author: Martin Fuerstenau, Oce Printing Systems
#         martin.fuerstenau_at_oce.com or Martin.fuerstenau_at_nagiossw.org
#
# Copyright (c) 2012, Martin Fuerstenau <martin.fuerstenau@oce.com>
#
# This module is free software; you can redistribute it and/or modify it
# under the terms of GNU General Public License (GPL) version 3.

#
# Purpose and features of the program:
#
# - check_snmp_cisco_wlc is a Nagios plugin to monitor the status of
#   Cisco Wireless Lan Controller (former Airespace)
#
# History and Changes:
# 
# - 10 Aug 2012 Version 1
#    - First released version.

#./check_snmp_cisco_wlc -H <hostaddress> -C <communitay-string>
# or
#./check_snmp_cisco_wlc -H <hostaddress> -r

use strict;
use Getopt::Long;

use File::Basename;
use Net::SNMP;



#--- Start presets and declarations -------------------------------------
# 1. Define variables

# General stuff
my $version = '1.0';
my $progname = basename($0);
my $help;                               # If some help is wanted....
my $NoA="";                             # Number of arguments handled over
                                        # the program
my $recover;                            # If called with this option only the file
                                        # in the plugincache will be deleted.
                                        # With the next run of the plugin
                                        # this file will be recreated and 
                                        # everything is fine

# Some SNMP stuff
my $result;                             # Points to result hash
my $key;                                # The key for the result hash
my $session;                            # Point to the SNMP session
my $error;                              # If shit happens....
my $oid;                                # To store OID
my $snmpversion;                        # SNMP version
my $snmpversion_def = 2;                # SNMP version default
my $snmpport;                           # SNMP port
my $snmpport_def = "161";               # SNMP port default
my $hostaddress;                        # Contains the target hostaddress
my $community;                          # Contains SNMP community of the target hostaddress

# Some OID presets
my $bsnAPDot3MacAddress=".1.3.6.1.4.1.14179.2.2.1.1.1";
my $bsnAPName=".1.3.6.1.4.1.14179.2.2.1.1.3";
my $bsnAPOperationStatus=".1.3.6.1.4.1.14179.2.2.1.1.6";

my $r_code = 0;                         # Exitcode for get_out. Default is 0
my $r_message;                          # Message for get_out
my $r_ap_unconf;                        # Unconfigured APs
my $r_ap_oper;                          # Operstaus not ok
my $multiline;                          # Multiline output in overview. This mean technically that
                                        # a multiline output uses a HTML <br> for the GUI instead of
                                        # Be aware that your messing connections (email, SMS...) must use
                                        # a filter to file out the <br>. A sed oneliner like the following
                                        # will do the job:
                                        # sed 's/<[^<>]*>//g'
my $multiline_def="\n";                 # Default for $multiline;
my $showerror;                          # If set switch to multiline (HTML) in case of an error.

# Some array/hash stuff
my %index2new_ap_name;                  # Contains the OID shortened to the index
                                        # and the AP name of a new AP
my %index2name;
my $new_index;
my %index2name_old;
my $old_index;
my $oper_stat;
my $NoAPs = 0;                          # Number of APs
my $NoAPs_old;                          # Number of APs old

my $plugin_cache="/var/nagios_plugin_cache";
my $dirhandle;                          # Point to the directory
my @files;                              # Files in that dir
my $AP_List;                            # Filename storing actual APs and indices            
my $AP_List_old;                        # Filename storing old APs and indices            

#--- End presets --------------------------------------------------------

# First we have to fix  the number of arguments

$NoA=$#ARGV;

Getopt::Long::Configure('bundling');
GetOptions
	("H=s" => \$hostaddress,      "hostaddress=s"    => \$hostaddress,
         "C=s" => \$community,        "community=s"      => \$community,
	 "v=s" => \$snmpversion,      "snmpversion=s"    => \$snmpversion,
	                              "multiline"        => \$multiline,
	                              "showerror"        => \$showerror,
         "r"   => \$recover,          "recover"          => \$recover,
         "h"   => \$help,             "help"             => \$help);

# Several checks to check parameters
if ($help)
   {
   help();
   exit 0;
   }

# Multiline output in GUI overview?
if ($multiline)
   {
   $multiline = "<br>";
   }
else
   {
   $multiline = $multiline_def;
   }

# Right number of arguments (therefore NoA :-)) )

if ( $NoA == -1 )
   {
   usage();
   exit 1;
   }


if (!$hostaddress)
   {
   print "Hostname or hostaddress not specified\n\n";
   usage();
   exit 1;
   }

if ($recover)
   {
   remove_data();
   exit 0;
   }

if (!$community)
   {
   $community = "public";
   print "No community string supplied - using public\n";
   }

if (!$snmpversion)
   {
   $snmpversion = $snmpversion_def;
   }

if ($snmpversion ne "1" )
   {
   if ($snmpversion eq "2c" )
      {
      $snmpversion = 2;
      }
   if ($snmpversion ne "2" )
      {
      print "SNMP version ($snmpversion) entered is neither 1 nor 2c. Only these are supported versions\n\n";
      usage();
      exit 1;
      }
   }

if (!$snmpport)
   {
   $snmpport = $snmpport_def;
   }

#
# So here starts the main section.------------------------------------------------------------------
#

# First open a session
($session, $error) = Net::SNMP->session( -hostname  => $hostaddress,
                                         -version   => $snmpversion,
                                         -community => $community,
                                         -port      => $snmpport,
                                         -retries   => 10,
                                         -timeout   => 10
                                        );

# If there is something wrong...exit

if (!defined($session))
   {
   printf("ERROR: %s.\n", $error);
   print "Exiting\n";
   exit 3;
   }

get_new_ap_name();

get_name();

# $AP_List;
# $AP_List_old;

$AP_List = $hostaddress . "_" . $NoAPs;

handle_historic_data();


# Now we get the operational status of the Access Point

$result = $session->get_table( -baseoid => $bsnAPOperationStatus );

# The Operation State of the AP. When AP associates with the 
# Airespace Switch its state will be associated. When Airespace
# AP is disassociated from the Switch, its state will be 
# disassociating. The state is downloading when the AP is 
# downloading its firmware.

# Enumerations:
# 1 - associated (Ok)
# 2 - disassociated (Critical)
# 3 - downloading (Warning)

foreach $key ( keys %$result)
        {
        $oper_stat = $$result{$key};
	    
        # We strip off the OID and stay with the index.
        $new_index = $key;
        $new_index =~ s/^.*14179\.2\.2\.1\.1\.6\.//;
        
        if ($oper_stat eq 1)
           {
           $r_ap_oper =  $r_ap_oper . "$index2name{$new_index} is associated (Ok)$multiline";
           }

        if ($oper_stat eq 2)
           {
           $r_ap_oper =  $r_ap_oper . "$index2name{$new_index} is disassociated (Critical)$multiline";

           if ($r_code < 2)
              {
              $r_code = 2;
              }
           }

        if ($oper_stat eq 3)
           {
           $r_ap_oper =  $r_ap_oper . "$index2name{$new_index} is downloading (Warning)$multiline";

           if ($r_code < 1)
              {
              $r_code = 1;
              }
           }
        }

if ( $r_code == 0 )
   {
   $r_message = "Every AP on WCL is ok.$multiline" . $r_ap_oper;
   }

if ($showerror)
   {
   $multiline = "<br>";
   $r_ap_oper =~ s/\n/\<br\>/g;
   $r_ap_unconf =~ s/\n/\<br\>/g;
   }

if ( $r_code == 1 )
   {
   $r_message = "Warning! One or more APs are unconfigured or downloading$multiline" . $r_ap_oper . $r_ap_unconf;
   }

if ( $r_code == 2 )
   {
   $r_message = "Critical! One or more APs are down or disassociated$multiline" . $r_ap_oper . $r_ap_unconf;
   }

# And now we leave
get_out($r_code, "$r_message");

# ---- Subroutines -------------------------------------------------------

sub get_new_ap_name()
    {
    my $mac;
    my $new_ap_name;
    my $tmp1;
    my $tmp2;
    my $tmp3;
    
    $result = $session->get_table( -baseoid => $bsnAPDot3MacAddress );

    foreach $key ( keys %$result)
            {
            $mac = $$result{$key};
            
            # Kick out leading 0x because it is a MAC address and not a
            # hex value. A regex would be more sophisticated and shorter.
            # But this works and was quicker to code :-))
            
            $mac =~ s/^0x//;
            $mac =~ s/^......//;
	    $tmp1 = $mac;
	    $tmp2 = $mac;
	    $tmp2 = $mac;
            $tmp1 =~ s/....$//;
            $tmp2 =~ s/^..//;
            $tmp2 =~ s/..$//;
            $tmp3 =~ s/^....//;
	    
	    # A new unconfigured AP has the name AP: and the
	    # last 3 bytes of the MAC address
	    
	    $new_ap_name = "AP:$tmp1:$tmp2:$tmp1";
            
	    # We strip off the OID and stay with the index.
	    $new_index = $key;
	    $new_index =~ s/^.*14179\.2\.2\.1\.1\.1\.//;
            $index2new_ap_name{$new_index} = $new_ap_name;
	    $new_index = "";
            }
    }

sub get_name()
    {
    my $ap_name;
    
    $result = $session->get_table( -baseoid => $bsnAPName );

    foreach $key ( keys %$result)
            {
            $ap_name = $$result{$key};
            
	    # We strip off the OID and stay with the index.
	    $new_index = $key;
	    $new_index =~ s/^.*14179\.2\.2\.1\.1\.3\.//;
            $index2name{$new_index} = $ap_name;
	    
	    # Increase the number of APs
            $NoAPs++;

            if ($ap_name != $index2new_ap_name{$new_index})
               {
               $r_ap_unconf =  $r_ap_unconf . "$ap_name unconfigured (warning)$multiline";

               if ($r_code < 1)
                  {
                  $r_code = 1;
                  }
               }
	    $new_index = "";
            }
    }

sub remove_data()
    {
    my $tmp_file;
    
    opendir ($dirhandle, $plugin_cache) || die "Couldn't open dir '$plugin_cache': $!";
    @files = readdir $dirhandle;
    foreach (@files)
            {
            $tmp_file = $_;
            if ($tmp_file =~ m/^$hostaddress.*$/)
               {
               unlink("$plugin_cache/$tmp_file") || die "Cant remove $plugin_cache/$tmp_file";
               }
            } 
    closedir $dirhandle;
    }


sub handle_historic_data()
    {
    my $AP_List_old_line;
    my @tmp_array;
    my %reverse_index2name;
    my $NoDelFile = 0;
    
    # First we look for the file in the cache dir
    opendir ($dirhandle, $plugin_cache) || die "Couldn't open dir '$plugin_cache': $!";
    @files = readdir $dirhandle;
    closedir $dirhandle;

    $AP_List_old = "@files";
    $AP_List_old =~ s/^.* $hostaddress/$hostaddress/;
    $AP_List_old =~ s/ .*$//;

    # If there is no file only the new file will be created

    if ($AP_List_old =~ m/$hostaddress.*$/)
       {
       $NoAPs_old = $AP_List_old;
       $NoAPs_old =~ s/^.*_//;

       # If we have less APs now as in the past it could be an
       # error. So we have to compare with the old stuff
       
       if ($NoAPs lt $NoAPs_old)
          {
          
          # Lets open the old stuff and put it in a hash
          open(OUT_AP_LIST_OLD, "< $plugin_cache/$AP_List_old");

          while (<OUT_AP_LIST_OLD>)
                {
                $AP_List_old_line="$_";
                chomp($AP_List_old_line);
                @tmp_array = split(/ /,$AP_List_old_line);
                $index2name_old{$tmp_array[0]} = $tmp_array[1];
               
                }
          close(OUT_AP_LIST_OLD);
         
          # So we try to find out what's the difference. reverse swaps index and value
          %reverse_index2name = reverse %index2name;
          @tmp_array = grep ! exists $reverse_index2name{ $_ }, values %index2name_old;
          
          foreach (@tmp_array)
                  {
                  $r_ap_oper =  $r_ap_oper . "$_ seems to be down (Critical)$multiline";
                  } 
          if ($r_code < 2)
             {
             $r_code = 2;
             $NoDelFile = 1;
             }
          }
       else
          {
          if ($NoAPs gt $NoAPs_old)
             {
             unlink("$plugin_cache/$AP_List_old") || die "Cant remove $plugin_cache/$AP_List_old";
             }
          }

       }

    if ($NoDelFile eq 0 )
       {
       # Writing the indices and values to a file

       open(OUT_AP_LIST, "> $plugin_cache/$AP_List");
   
       foreach $new_index ( keys %index2name)
               {
               print OUT_AP_LIST "$new_index $index2name{$new_index}\n";
               }
    
       close(OUT_AP_LIST);
       }
    }


sub get_out()
    {
    my $exitcode;
    my $msg2nagios;

    $exitcode = "$_[0]";
    $msg2nagios = "$_[1]";

    print "$msg2nagios";

    # Don't forget to close the session to be clean.
    $session->close();

    exit $exitcode;
    }

sub usage()
    {
    print "Usage: ";
    print "$progname ";
    print "[ -H <hostaddress> ] ";
    print "[ -t <timeout> ] ";
    print "[ -r] ";
    print "[ -C|--community=<community> ] ";
    print "[ -v|--snmpversion=<1|2c> ] ";
    print "[--port=<SNMP portnumber>] ";
    print "[--showerror] ";
    print "[--multiline]\n\n";
    }


sub help ()
    {
    print "This monitoring plugin is free software, and comes with ABSOLUTELY NO WARRANTY.\n";
    print "It may be used, redistributed and/or modified under the terms of the GNU\n";
    print "General Public Licence (see http://www.fsf.org/licensing/licenses/gpl.txt).\n\n";
    
    usage();

    print "This plugin checks the status of the Access Points for a Cisco Wireless Lan Controller (WLC).\n\n";

    print "-h, --help                  Print detailed help screen\n";
    print "-V, --version               Print version information\n";
    print "-H, --hostaddress=STRING    hostaddress/IP-Adress to use for the check.\n";
    print "-C, --community=STRING      SNMP community that should be used to access the switch.\n";
    print "-v, --snmpversion=STRING    Possible values are 1 or 2c. Version 3 is not supported.\n";
    print "    --port=INTEGER          If other than 161 (default) is used)\n";
    print "-t, --timeout=INTEGER       Seconds before plugin times out (default: 15)\n";
    print "-r                          Recover - It kicks out old collected data so that the next check is ok.\n";
    print "    --multiline             Multiline output in overview. This mean technically that a multiline\n";
    print "                            output uses a HTML <br> for the GUI instead of \\n\n";
    print "                            Be aware that your messing connections (email, SMS...) must use\n";
    print "                            a filter to file out the <br>. A sed oneliner will do the job.\n";
    print "    --showerror             Multiline output in overview ind case of an error. uses <br>. See above.\n";
    }


