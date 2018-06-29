#!/usr/bin/perl
use strict;
use Text::Wrap;
use Term::ANSIColor;
use Cwd;
#use WWW::Mechanize;

my $CUR_DIR = cwd;
my ($SVN_BASE_rev,$SVN_HEAD_REV);
my $SVN_URL;
my $numArgs = scalar @ARGV;
if( $numArgs == 3 ){
	$SVN_BASE_rev = "$ARGV[0]";
	$SVN_URL="$ARGV[1]";
	$SVN_HEAD_REV="$ARGV[2]";
}elsif( $numArgs == 2 ){
	if ( (defined $ARGV[0] && $ARGV[0] =~ /[0-9]+/) && (defined $ARGV[1] && $ARGV[1] =~ /https\:/) ){
		$SVN_BASE_rev = "$ARGV[0]";
		$SVN_URL="$ARGV[1]";
		$SVN_HEAD_REV=`svn info $SVN_URL | grep "Last Changed Rev:" | cut -d ' ' -f4`;
		$SVN_HEAD_REV =~ s/^\s+|\s+$//g;
	}elsif( (defined $ARGV[0] && $ARGV[0] =~ /https\:/) && (defined $ARGV[1] && $ARGV[1] =~ /[0-9]+/)){
		$SVN_URL="$ARGV[0]";
		$SVN_BASE_rev ="";
		$SVN_HEAD_REV="$ARGV[1]";
	}else{
		print color("red"),"If you want define TWO ARGUMENTS, Define Arguments Correctly\n",color("reset");
		print color("red"),"Pass 1st argument either as svn_url or svn base revision \nif 1st argument as SVN_BASE_REV then 2nd argument should be SVN_URL\n";
		print "\tOR \n1st argument is SVN_URL and 2nd argument should be as SVN_HEAD_REV (DEFAULT WILL BE HEAD REVISION)\n ",color("reset");
		exit 1;
	}
}elsif( $numArgs == 1){
	if (defined $ARGV[0] && $ARGV[0] =~ /https\:/){
		$SVN_URL="$ARGV[0]";
		$SVN_HEAD_REV=`svn info $SVN_URL | grep "Last Changed Rev:" | cut -d ' ' -f4`;
		$SVN_HEAD_REV =~ s/^\s+|\s+$//g;
		$SVN_BASE_rev ="";
	}else{
		print color("red"),"Define Arguments Correctly \n",color("reset");
		print color("red"),"If you want define single argument, pass only one argument as svn_url repo link \n ",color("reset");
		exit 1;
	}
}else{
	print color("red"),"Define Arguments Correctly\n",color("reset");
        print color("red"),"3 ARGUMENTS, 1st as SVN_Base_revision , 2nd as SVN_URL, 3rd as SVN_HEAD_REVISION\n\tOR\n",color("reset");
	print color("red"),"2 ARGUMENTS, Either 1st as SVN_Base_revision and 2nd as SVN_URL OR 1st as SVN_URL and 2nd as SVN_HEAD_REV\n\tOR\n",color("reset");
	print color("red"),"only 1 ARGUMENT, 1st as SVN_URL (DEFAULT SVN_HEAD_REV will be HEAD)\n",color("reset");
        exit 1;
}
# testing for website url response
#my $agent = WWW::Mechanize->new( autocheck => 0 );
#my $test_url=$agent->get($SVN_URL);
#if ((!$test_url->is_success) ) {
#	print("unable to reach svn_url link:$SVN_URL.\n");
#	exit 1;
#}
#Argument null or undefined will have defaultly Last Changed Revision value;
my ($LINE,$F1,$F2,$OLD_REV,$first_line);
my $TAR_DIFF = join("/",$CUR_DIR,"tar_diff_log.txt");
if( -f $TAR_DIFF ){
	unlink("$TAR_DIFF") or die $!;
}
if (-f "pack.txt"){
	unlink("pack.txt") or die $!;
}
if (-f "temp.txt"){
        unlink("temp.txt") or die $!;
}
my $FLAG=0;
my (@files,@allfiles);
#Reading tar files from hidden osc directory
my $dir = "$CUR_DIR/.osc";
opendir(DIR,$dir) or die "couldn't open $dir directory:$!" ;
	@files = grep {/\.tar\.|\.tgz/} readdir(DIR);
closedir DIR;
#Read files from current directory
opendir(DIR,$CUR_DIR)or die "couldn't open $CUR_DIR directory:$!" ;;
	@allfiles = grep{ ! /^\./ && !/\.changes$/ && !/tardiff/ && !/\.tar\./ && !/baselibs.conf/} readdir(DIR);
closedir DIR;

if ((scalar @files) == 0){
	print "no tar files in current directory\n";
	$FLAG=1;
}
my $first_counter=0;
my (@TAR,@TAR_NAME);
if ($FLAG == "0")
{
	unless ( -e "tardiff")
	{
		system("svn export -q https://svn.provo.novell.com/svn/blr-wgpcm/branches/ramakrishna/tardiff --force");
	}
	#writing modified files in tar to text file
	foreach (@files)
	{
		@TAR = split '\.',$_;
		push @TAR_NAME,$TAR[0];
		system ("sh $CUR_DIR/tardiff -f $CUR_DIR/.osc/$_ $_ | grep '^+++' >> $TAR_DIFF");
		open(MYFILE,"<$TAR_DIFF")or die "couldn't open tardiff log file:$!";
			$first_line=<MYFILE>;
		close(MYFILE)or die "couldn't close tardiff log file:$!";
		if ($first_line =~ m/ no output \(probably identical\)/ && $first_counter== 0)
		{
			truncate $TAR_DIFF,0;
			$first_counter=1;
		}
	}
	#checking file is empty or exist
	if ( -z $TAR_DIFF || $first_line =~ m/ no output \(probably identical\)/ || !-e  $TAR_DIFF )
	{
		print color("red"),"tar diff log file is empty\n",color("reset");
		$FLAG=1;
	}
}
my $changefile;
#to read latest revision form changelog file
if ( $SVN_BASE_rev eq "" || !defined $SVN_BASE_rev ){
	$changefile=glob "*.changes";
	open(MYFILE,"<","$changefile")or die "couldn't open changelog file:$!";
	while($LINE = <MYFILE>){
		if ($LINE =~ /\- r[0-9]+/){
			($F1,$F2)=split ' ', $LINE;
			$F2 =~ s/^\s+|\s+$//g;
			$OLD_REV=substr($F2,1);
			$OLD_REV =~ s/^\s+|\s+$//g;
			last;
		}
	}
	close(MYFILE)or die "couldn't close changelog file:$!";
	$SVN_BASE_rev = $OLD_REV;
}
# if revision from changelog file and latest revision from svn repo equals exit script
if ("$SVN_BASE_rev" ge "$SVN_HEAD_REV" )
{
	print color("red"),"no changes in svn repo\n",color("reset");
	&unlink_pack;
	exit;
}
my $package_name=split '\.',$changefile;
push @TAR_NAME,$package_name;

print color("blue"),"starting revision of this package changelog:$SVN_BASE_rev \n",color("reset");
print color("blue"),"Head revision of this package changelog:$SVN_HEAD_REV \n",color("reset");
my $SVN_LOG=join("/",$CUR_DIR,"svnlog_package.txt");
if (-f $SVN_LOG){
	unlink("$SVN_LOG") or die $!;
}
my $SVN_OLD_REV=int($SVN_BASE_rev)+1;
system("svn log -r $SVN_OLD_REV:$SVN_HEAD_REV -v $SVN_URL >> $SVN_LOG");
if(-z $SVN_LOG || !-e $SVN_LOG)
{
	print color("blue"),"there is no changes in svn repo or svn log files is not created, please check\n",color("reset");
	exit 1;
}
my (@AR_REV,@ARRAY_STR,@ARRAY_STR1);
my ($STRi,$LN);
# tardiff log file is not empty or non zero file it will enter to loop
if($FLAG == "0")
{
	open(MYFILE,"<$TAR_DIFF")or die "couldn't open tardiff log file:$!";
	while($LINE = <MYFILE>){
		next if ($LINE =~ m/ no output \(probably identical\)/);
		@AR_REV=split ' ', $LINE;
		$AR_REV[1]=~s/^\s+|\s+$//g;
		my $STR=substr($AR_REV[1],4);
		push(@ARRAY_STR1,$STR);
	}
	foreach $_ (@ARRAY_STR1)
	{
		my $COUNTER=0;
		#if string contains tar name or package name, will remove
		foreach $LN (@TAR_NAME){
			if ($_ =~ $LN)
			{
				$_ =~ s/$LN\///;
				push(@ARRAY_STR,$_);
				$COUNTER=1;
			}
			last if $COUNTER == 1 ;
		}
		if ($COUNTER == 0){
			push(@ARRAY_STR,$_);
		}
	}
	close(MYFILE)or die "couldn't close tardiff log file:$!";

}
my $SVN_REV_ONLY=join("/",$CUR_DIR,"svn_rev_only.txt");
if (-f $SVN_REV_ONLY){
	unlink("$SVN_REV_ONLY") or die $!;
}
my $i=0;
my (@temp,$n,@FD1,@FD2,$OUTFILE,$OUTFILE1,$INFILE,$LINE1,$INFILE1);
#splitting svn log file to multiple temp files
open(MYFILE,$SVN_LOG)or die "couldn't open svn log file:$!";
while($LINE = <MYFILE>){
	if ($LINE =~ m/^r[0-9]+/){
		@FD1=split ' ', $LINE;
		$FD1[0] =~ s/^\s+|\s+$//g;
		open $OUTFILE, ">>", "$SVN_REV_ONLY";
		print $OUTFILE "$FD1[0]\n";
		close($OUTFILE)or die "couldn't close svn log file:$!";
	}
	if ($LINE =~ /^------*------$/){
		$i=$i+1;
		next;
	}else{
		open ($OUTFILE1,">>","temp$i") or die "couldn't open file to write temp$i log file:$!";
		print $OUTFILE1 $LINE;
		close($OUTFILE1)or die "couldn't close temp$i log file:$!";
	}
}
close(MYFILE);
#file contains revisions from svn_log file
if (-z $SVN_REV_ONLY || !-f $SVN_REV_ONLY){
	print color("red"),"$SVN_REV_ONLY file not found\n",color("reset");
	exit 1;
}
#pushing all other existing files beyond tar changes in current directory
foreach(@allfiles){
	push @ARRAY_STR,"$_";
}
my ($MYSTR,@ARRAY_STRING);
#collecting actual Required revisions while matchings between temp and Array_String
foreach $MYSTR (@ARRAY_STR)
{
	for ($n=1;$n<$i;$n++)
	{
		$temp[$n]=join("/",$CUR_DIR,"temp$n");
		open($INFILE,$temp[$n])or die "couldn't open $temp[$n] log file:$!";
		while($LINE = <$INFILE>){
			if ($LINE =~ "$MYSTR")
			{
				open($OUTFILE,$temp[$n])or die "couldn't open inner $temp[$n] log file:$!";
				while($LINE1 = <$OUTFILE>){
					if ($LINE1 =~ m/^r[0-9]+ /){
						@FD2=split ' ', $LINE1;
						$FD2[0] =~ s/^\s+|\s+$//g;
						push(@ARRAY_STRING,$FD2[0]);
					}
				}
				close($OUTFILE)or die "couldn't close inner $temp[$n] log file:$!";
			}
		}
		close($INFILE)or die "couldn't close $temp[$n] log file:$!";
	}
}
if ((scalar @ARRAY_STRING) == 0)
{
	print color("red"),"no changes for this package\n",color("reset");
	&unlink_pack;
        exit 0;
}
#sorting and uniq values of revisions
sub sort_rev(\@){
	my @uniqar;my %seen;
	foreach my $value (@_){
		if(!$seen{$value}++){
		push @uniqar,$value;
		}
	}
	my @SORTAR = reverse sort @uniqar;
}
my @AR_SORT=&sort_rev(@ARRAY_STRING);
if ( @AR_SORT eq "0" )
{
	print color("red"),"no changes for this package\n",color("reset");
	&unlink_pack;
	exit 0;
}
my (@finalrev,@finalid,@final_lines,%final_line,%final_rev,%final_id,%final_par,$deal);
#function to create Temporary changelog file
&temp_changelog(@AR_SORT);
#function to copying temp changelog to acual changelog file
&create_changelog('pack.txt');
&unlink_pack;
#removing all unwanted files
sub unlink_pack{
	unlink("$SVN_LOG") or die $!;
	unlink("$SVN_REV_ONLY") or die $!;
	if (-f $TAR_DIFF){
		unlink("$TAR_DIFF") or die $!;
	}
	if (-f "pack.txt"){
		unlink("pack.txt") or die $!;
	}
	if (-f "temp.txt"){
	        unlink("temp.txt") or die $!;
	}
	if (-f "tardiff"){
		unlink("tardiff") or die $!;
	}
	for ($n=1;$n<$i;$n++){
		$temp[$n]=join("/",$CUR_DIR,"temp$n");
		unlink($temp[$n]);
	}
}
sub temp_changelog(\@)
{
	foreach $MYSTR (@_){
		for ($n=1;$n<$i;$n++){
			$temp[$n]=join("/",$CUR_DIR,"temp$n");
			open(MYFILE,$temp[$n])or die "couldn't open $temp[$n] log file for changelog function:$!";
			while($LINE = <MYFILE>){
				if ($LINE =~ $MYSTR){
					my $spool=0;
					open($INFILE,$temp[$n])or die "couldn't open inner $temp[$n] log file for changelog function:$!";
					while($LINE1 = <$INFILE>){
						if($LINE1 =~ $MYSTR){
							@finalrev=split ' ',$LINE;
							$final_rev{$MYSTR}=join(' | ',$finalrev[0],$finalrev[2]);
							$final_rev{$MYSTR} =~ s/^\s+|\s+$//g;
							$spool=0;
						}
						if ($LINE1 =~ /ID\s*:\s*\w*#[0-9]+/ || $LINE1 =~ /ID\s*:\s*[b|B,d|D]-[0-9]+/ ){
							@finalid=split ':',$LINE1;
							$finalid[1] =~ s/^\s+|\s+$//g;
							#if ($finalid[1] =~ "^#0+"){
							#	$finalid[1] = "";
							#}
							$final_id{$MYSTR}=join(' | ',$final_rev{$MYSTR},$finalid[1]);
							if($final_id{$MYSTR} eq " "){
								print color("red"),"\$final_id{\$MYSTR}= $final_id{$MYSTR} got null,please check\n";
								exit 1;
							}
							$spool=0;
						}
						if($spool=="1"){
							chomp($final_line{$MYSTR});
							$final_line{$MYSTR}=join(' ',"$final_line{$MYSTR}","$LINE1");
							if ($LINE1 =~ m/^\s+$/ || $LINE1 eq "\n")
							{
								$spool=0;
							}
							next;
						}
						if ($LINE1=~ /^Description\s*:/ ){
							my @lines=split /^Description\s*:/,$LINE1 ;
							$final_line{$MYSTR}="$lines[1]";
							$spool=1;
						}
						if(eof){ $spool=0; }
					}
					close($INFILE)or die "couldn't close inner $temp[$n] log file for changelog function:$!";
					$Text::Wrap::columns = 70;
					$final_par{$MYSTR}=join(' - ',$final_id{$MYSTR},"$final_line{$MYSTR}");
					$final_par{$MYSTR} =~ s/^\s+|\s+$//g;
					open($OUTFILE,'>>','pack.txt')or die "couldn't open file to write in changelog function:$!";
					$deal=wrap('- ', '  ',"$final_par{$MYSTR}")."\n";
					print $OUTFILE "$deal";
					close($OUTFILE)or die "couldn't close file to write in changelog function:$!";
				}
			}
			close(MYFILE)or die "couldn't close $temp[$n] log file for changelog function:$!";
		}
	}
}
sub create_changelog{
	open($INFILE,'<',"pack.txt")or die "couldn't open log file from changelog function:$!";
	while($LINE = <$INFILE>)
	{
		open($OUTFILE1,'>>',"tmp.txt")or die "couldn't open to write log file inside create_change function:$!";
		print $OUTFILE1 "$LINE";
		if(eof){print $OUTFILE1 "\n";}
		close($OUTFILE1)or die "couldn't close to write log file inside create_change function:$!";
	}
	close($INFILE)or die "couldn't close log file from changelog function:$!";
	my ($comp_changelogfile) = glob ("*.changes");
	open($INFILE1,'<',"$comp_changelogfile")or die "couldn't open local changelog file from current directory:$!";
	while($LINE1 = <$INFILE1>)
	{
		open($OUTFILE,'>>',"tmp.txt")or die "couldn't open final log file to write:$!";
		print $OUTFILE "$LINE1";
		close($OUTFILE)or die "couldn't close final log file :$!";
	}
	close($INFILE1)or die "couldn't close local changelog file from current directory:$!";
	unlink("$comp_changelogfile");
	rename("tmp.txt","$comp_changelogfile")|| die "error in renaming";
	system("osc vc -m ' '");
	rename("$comp_changelogfile","temp.txt")|| die "error in renaming";
	system("sed '3,4d' temp.txt >>  $comp_changelogfile");
}
