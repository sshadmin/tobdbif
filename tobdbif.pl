#!/usr/bin/env perl
use 5 ;
use warnings ;
use strict ;
use DB_File ;

use Getopt::Long ;
use Pod::Usage ;

my $version = '0.0.1'; # use '' to print 'development version'
my $customScriptName = ''; # use '' if you want autodetection
my $projectUrl = ''; # use '' if you don't need this option

### routine stub declaration ###
sub getScriptName;
sub help;
sub exitScript;
sub outputDebug;
sub trim;
sub parseArgs;

### main code ###
my $exitMsg = '';
my $exitStatus = ''; # choose OK, WARNING or CRITICAL .. else CRITICAL

# parsing non positional options
my $opts = {
  'quiet' => {
    'short'        => 'q',
    'long'         => 'quiet',
    'type'         => 'b',
    'mandatory'    => 'false',
  },
  'force' => {
    'short'        => 'f',
    'long'         => 'force',
    'type'         => 'b',
    'mandatory'    => 'false',
  },
  'create' => {
    'short'        => 'C',
    'long'         => 'create',
    'type'         => 's',
    'mandatory'    => 'false',
  },
  'read' => {
    'short'        => 'R',
    'long'         => 'read',
    'type'         => 's',
    'mandatory'    => 'false',
  },
  'update' => {
    'short'        => 'U',
    'long'         => 'update',
    'type'         => 's',
    'mandatory'    => 'false',
  },
  'delete' => {
    'short'        => 'X',
    'long'         => 'delete',
    'type'         => 's',
    'mandatory'    => 'false',
  },
  'dump' => {
    'short'        => 'Z',
    'long'         => 'dump',
    'type'         => 's',
    'mandatory'    => 'false',
  }
  # 'mandatory'        => {
  #   'short'        => 'm',
  #   'long'         => 'mandatory',
  #   'type'         => 's',
  #   'mandatory'    => 'true',
  #   'missingText'  => 'You should specify a mandatory warning text here'
  # },
  # 'nonmandatory' => {
  #   'short'        => 'n',
  #   'long'         => 'nonmandatory',
  #   'type'         => 's',
  #   'mandatory'    => 'false',
  # }
};
my $config = &parseArgs($opts);

# parsing positional options
my $targetDBFile = shift or &exitScript ('CRITICAL', 'Please specify a target DBFile to work on');
&outputDebug('Target DBFile is '.$targetDBFile,$config);
tie my %h, "DB_File", $targetDBFile, O_RDWR|O_CREAT, 0666, $DB_HASH or die "Cannot open/write file ".$targetDBFile.": $!\n";
&outputDebug('DB_File opened succesfully '.$targetDBFile,$config);

if (!
      (
        exists($config->{'create'}) or
        exists($config->{'read'}) or
        exists($config->{'update'}) or
        exists($config->{'delete'}) or
        exists($config->{'dump'})
      )
    ){
  $exitStatus='USAGE';
  $exitMsg='You should choose one DB option from C(create), R(read), U(update), X(delete) or Z(dump)';
};
if (exists($config->{'create'})) {
  &outputDebug('Create mode activated on file '.$targetDBFile,$config);
  $config->{'create'} =~ m/^\((\w+),(\w+)\)$/;
  my ($argKey, $argValue) = (($1 or ''),($2 or ''));
  &outputDebug('Received argKey -> '.$argKey.' argValue -> '.$argValue,$config);
  if ($config->{'force'} or !(exists($h{$argKey}))){
    $h{$argKey} = $argValue;
  } else {
    &exitScript('CRITICAL','Key already found in DB, use U(update) or f(force) option');
    # $exitStatus='CRITICAL';
    # $exitMsg='Key already found in DB, use U(update) or f(force) option';
  };
  delete($config->{'create'});
  &outputDebug('argKey -> '.$argKey.' argValue -> '.$argValue.' inserted correctly',$config);
  # $exitStatus='OK';
  $exitMsg = ($config->{'quiet'}?'':$argKey.' -> '.$argValue.' inserted in '.$targetDBFile);
  &exitScript('OK',$exitMsg);
} elsif (exists($config->{'read'})) {
  &outputDebug('Read mode activated on file '.$targetDBFile,$config);
  my $argKey = $config->{'read'};
  &outputDebug('Requested key -> '.$argKey,$config);
  if (exists($h{$argKey})){
    # &exitScript('OK',$h{$argKey});
    $exitStatus='OK';
    print $h{$argKey};
  } else {
    $exitStatus = 'CRITICAL';
    &outputDebug('Requested key -> '.$argKey.' not found',$config);
    $exitMsg='Requested key -> '.$argKey.' not found';
  };
} elsif (exists($config->{'update'})) {
  &outputDebug('Update mode activated on file '.$targetDBFile,$config);
  $config->{'update'} =~ m/^\((\w+),(\w+)\)$/;
  my ($argKey, $argValue) = (($1 or ''),($2 or ''));
  &outputDebug('Received argKey -> '.$argKey.' argValue -> '.$argValue,$config);
  if ($config->{'force'} or exists($h{$argKey})){
    $h{$argKey} = $argValue;
  } else {
    # &exitScript('CRITICAL','Key not found in DB, use C(create) or f(force) option');
    $exitStatus='CRITICAL';
    $exitMsg='Key not found in DB, use C(create) or f(force) option';
  };
  delete($config->{'update'});
} elsif (exists($config->{'delete'})) {
  &outputDebug('Delete mode activated on file '.$targetDBFile,$config);
  my $argKey= $config->{'delete'};
  &outputDebug('Received argKey -> '.$argKey,$config);
  if ($config->{'force'} or exists($h{$argKey})){
    delete $h{$argKey};
  } else {
    # &exitScript('CRITICAL','Key not found in DB, check the specified key or use f(force) option to disable warnings');
    $exitStatus='CRITICAL';
    $exitMsg='Key not found in DB, check the specified key or use f(force) option to disable warnings';
  };
  delete($config->{'delete'});
} elsif (exists($config->{'dump'})) {
  &outputDebug('Dump mode activated on file '.$targetDBFile,$config);
  delete($config->{'dump'});
};
untie(%h);

### actual routine code ###
sub exitScript {
  my $exitStatus = (&trim(shift) or 'CRITICAL');
  my $exitMessage=  (
                      &trim(shift) or
                      ($exitStatus eq 'OK'?'':'Internal script error')
                    );

  &help($exitMessage) if ($exitStatus eq 'USAGE');

  # print ($exitStatus.' - '.$exitMessage."\n") ; # use in Nagios
  print ($exitMessage."\n") ;

  if ($exitStatus eq 'OK')           {
    exit(0);
  } elsif ($exitStatus eq 'WARNING') {
    exit(1);
  } elsif ($exitStatus eq 'CRITICAL') {
    exit(2);
  } elsif ($exitStatus eq 'USAGE') {
    exit(64); # as defined by standards
  } else  { # UNKNOW (3) or other
    exit(3);
  };
};

sub getScriptName {
  my $script_name = ($customScriptName or $0) ; # $customScriptName is global to the script
  return $script_name
};

sub help {
  my $helpBodyTxt = (shift . "\n" or '');
  my $script_version = ($version or 'development version'); # $version is global to the script
  my $script_project_url = ($projectUrl or ''); # $projectUrl is global to the script

  my $script_name = &getScriptName();

  $helpBodyTxt .= $script_name.' ('.$script_version.') ';
  $helpBodyTxt .= 'Url:'.$script_project_url.' ' if ($script_project_url ne '');
  $helpBodyTxt .= 'help'."\n\n" ;
  pod2usage(-message=>$helpBodyTxt, -verbose=>99);

  exit 0 ;
};

sub outputDebug {
  my $message = (shift or '');
  my $config = (shift or ());

  use File::Basename qw(dirname);
  use POSIX qw(strftime);

  # %d   giorno del mese (es.: 01)
  # %m   mese (01..12)
  # %T   ora; come %H:%M:%S
  # %Y   anno
  # %z   +hhmm fuso orario numerico (es: -0400)
  my $timeformat = '%d-%m-%Y_%H:%M:%S_(%z)' ;
  my $timestamp = strftime($timeformat,localtime());
  my $debugMessage = '* '.$timestamp.' - '.$message ;

  my $script_name = &getScriptName();
  if ($config->{'debug_in_tty'}) {
    print $debugMessage."\n";
  };
  if ($config->{'debug_in_file'}) {
    my $logFileName = '';
    if ( ($config->{'debug_in_file'}) and
         (-w dirname($config->{'debug_in_file'})) ){
        $logFileName = $config->{'debug_in_file'};
      } else {
      my $requestedLogFile = $config->{'debug_in_file'};
      my $exitStatus = 'CRITICAL';
      my $exitMsg = "Can't write requested logfile ".$requestedLogFile;
      &exitScript($exitStatus,$exitMsg);
    };
    open ( my $logFileHandler , '>>' , $logFileName );
      printf $logFileHandler &trim($debugMessage)."\n" ;
    close $logFileHandler ;
  };

  return '1' ;
};

sub trim {
  my $string = (shift or '');
    $string =~ s/^\P{IsPrint}+//g;
    $string =~ s/\P{IsPrint}+$//g;
  return $string;
};

sub parseArgs {
  my $opts = (shift or ());
  # # example hash options usage
  # $opts->{'arg_option'} = {
  #   'short'        => 'a',            # short option argv char (ex: -a)
  #   'long'         => 'arg_option',   # long option argv string (ex: --arg_option)
  #   'type'         => 's',            # option type s(tring), i(nteger), b(oolean)
  #   'mandatory'    => 'false'         # mandatory option (true/false)
  #   'missingText'  => 'You should specify this option' # Error message used if option is not specified
  # };
  # # this will generate $parsed_config{'a'} AND/OR $parsed_config{'arg_option'}
  $opts->{'debug_in_tty'} = {
    'short'        => 'd',
    'long'         => 'debug_in_tty',
    'type'         => 'b',
    'mandatory'    => 'false'
  };
  $opts->{'debug_in_file'} = {
    'short'        => 'D',
    'long'         => 'debug_in_file',
    'type'         => 's',
    'mandatory'    => 'false'
  };
  $opts->{'help'}          = {
    'short'        => 'h',
    'long'         => 'help',
    'type'         => 'b',
    'mandatory'    => 'false'
  };

  my @rawArgs = () ;
  my $parsedConfig = () ;
  my $mandatoryOpts = ();

  foreach my $opt (keys(%$opts)){
    my ($tmpShortArg, $tmpLongArg) = ('','');
    # args type parsing
    if(exists($opts->{$opt}->{'type'})){
      if(($opts->{$opt}->{'type'} eq 's') or ($opts->{$opt}->{'type'} eq 'i')){
        # string (s) or integer (i)
        $tmpShortArg = $opts->{$opt}->{'short'}.'='.$opts->{$opt}->{'type'} if ($opts->{$opt}->{'short'});
        $tmpLongArg = $opts->{$opt}->{'long'}.'='.$opts->{$opt}->{'type'} if ($opts->{$opt}->{'long'});
      } elsif ($opts->{$opt}->{'type'} eq 'b') {
        # boolean (b)
        $tmpShortArg = $opts->{$opt}->{'short'} if ($opts->{$opt}->{'short'});
        $tmpLongArg = $opts->{$opt}->{'long'} if ($opts->{$opt}->{'long'});
      };
    };
    # args
    push(@rawArgs,$tmpShortArg) if ($tmpShortArg);
    push(@rawArgs,$tmpLongArg) if ($tmpLongArg);

    if($opts->{$opt}->{'mandatory'} and $opts->{$opt}->{'mandatory'} ne 'false' ){
      $mandatoryOpts->{$opt}->{'short'} = $opts->{$opt}->{'short'};
      $mandatoryOpts->{$opt}->{'long'}  = $opts->{$opt}->{'long'};
    };
  };

  Getopt::Long::Configure ("bundling");
  GetOptions(\%$parsedConfig, @rawArgs);

  if($parsedConfig->{'h'} or $parsedConfig->{'help'}){
    &help();
  };
  foreach my $mandatoryOpt (keys(%$mandatoryOpts)){
    if  (!
          (
            exists($parsedConfig->{$mandatoryOpt}->{'short'}) or
            exists($parsedConfig->{$mandatoryOpt}->{'long'})
          )
        ){
      &help($opts->{$mandatoryOpt}->{'missingText'});
    };
  };

  my $finalParsedConfig ;
  foreach my $opt (keys(%$opts)){
     if(
        exists($parsedConfig->{$opts->{$opt}->{'short'}}) or
        exists($parsedConfig->{$opts->{$opt}->{'long'}})
      ) {
      if($opts->{$opt}->{'type'} eq 'b') {
        $finalParsedConfig->{$opt} = 'true' ;
      } else {
        if (exists($parsedConfig->{$opts->{$opt}->{'short'}})){
          $finalParsedConfig->{$opt} = $parsedConfig->{$opts->{$opt}->{'short'}} ;
        };
        if (exists($parsedConfig->{$opts->{$opt}->{'long'}})){
          $finalParsedConfig->{$opt} = $parsedConfig->{$opts->{$opt}->{'long'}} ;
        };      };
    };
  };

  return $finalParsedConfig ;
};

__END__
Put your doc here
__cut__