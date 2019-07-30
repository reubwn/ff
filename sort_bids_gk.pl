#!/usr/bin/env perl

## author: reubwn 2019

use strict;
use warnings;

use Getopt::Long;
use Sort::Naturally;
use Data::Dumper qw(Dumper);

my $usage = "
SYNOPSIS
  Sort the feckin' GK bidding
  Requires bidding form in CSV (comma-delimited) format
  Requires team name consistency across the multiple bids

OPTIONS [* required]
  -c|--csv  [FILE]* : bidding form as CSV
  -h|--help         : this message
\n";

my ($csv_file, $help, $debug);

GetOptions (
  'c|csv=s' => \$csv_file,
  'h|help' => \$help,
  'd|debug' => \$debug
);

die "$usage" unless ( $csv_file );
die "$usage" if ( $help );

my (%bidders, %players, %player_hash, %bidders_hash, %winner_of);
my (%first_bids, %second_bids, %third_bids);
my (%winners_so_far);

open (my $IN, $csv_file) or die $!;
while (my $line = <$IN>) {
  next if $. == 1;
  chomp $line;
  my @F = split (/,/, $line);

  (@F) = map { $_ =~ s/fc//i; $_ } @F;
  (@F) = map { $_ =~ s/^\s+|\s+$//g; $_ } @F;
  (@F) = map { $_ =~ s/^(man c|manchester city|manchester c|city)$/man city/i; $_ } @F;
  (@F) = map { $_ =~ s/^(man u|manchester utd|manchester u|manchester united|utd)$/man utd/i; $_ } @F;
  (@F) = map { $_ =~ s/^(tottenham hotspur|spurs|spuds)$/tottenham/i; $_ } @F;
  (@F) = map { $_ =~ s/^(west ham utd|hammers)$/west ham/i; $_ } @F;
  (@F) = map { $_ =~ s/^leicester city$/leicester/i; $_ } @F;
  (@F) = map { $_ =~ s/^(wanderers|wolverhampton wanderers)$/wolves/i; $_ } @F;
  (@F) = map { $_ =~ s/^palace$/crystal palace/i; $_ } @F;
  (@F) = map { uc } @F;

  my $bidder = $F[1]=~s/\s+/\_/gr;
  my $player = $F[2]=~s/\s+/\_/gr;
  $bidders{$bidder}++;
  $players{$player}++;
  # my @a = ($F[3], $F[4], $F[5]);
  # my @b = map { join ("|", $bidders{$bidder},$_,$bidder) } @a;
  # my @c = map { join ("|", $bidders{$bidder},$_,$player) } @a;
  # push ( @{$player_hash{$player}}, @b );
  # foreach (@c) {
  #   # print "$_\n";
  #   push ( @{$bidders_hash{$bidder}}, $_);
  # }
  if ($bidders{$bidder} == 1) {
    $first_bids{$player}{$bidder}{1} = $F[3]; ## %first_bids represents 1st-round bids
    $first_bids{$player}{$bidder}{2} = $F[4];
    $first_bids{$player}{$bidder}{3} = $F[5];
  } elsif ($bidders{$bidder} == 2) {
    $second_bids{$player}{$bidder}{1} = $F[3];
    $second_bids{$player}{$bidder}{2} = $F[4];
    $second_bids{$player}{$bidder}{3} = $F[5];
  } elsif ($bidders{$bidder} == 3) {
    $third_bids{$player}{$bidder}{1} = $F[3];
    $third_bids{$player}{$bidder}{2} = $F[4];
    $third_bids{$player}{$bidder}{3} = $F[5];
  }
  push ( @{$player_hash{$player}}, $bidder );
  push ( @{$bidders_hash{$bidder}}, $player );
}
close $IN;

print STDERR "[INFO] Number of bidders: ".scalar(keys %bidders)."\n";
print STDERR "[INFO] Number of players bid on: ".scalar(keys %players)."\n";
foreach (nsort keys %players) {
  print STDERR "[INFO]   $_ : $players{$_}\n";
}

unless ( $debug ) {
  print STDERR "[INFO] Sorting Round #1 bids...\n";
  sleep 1; #print STDERR "*";sleep 1; print STDERR "*";sleep 1; print STDERR "*"; sleep 1;
}

################################
## FIRST ROUND
################################
print STDERR "\n## FIRST-ROUND\n\n" if ( $debug );

foreach my $player (nsort keys %first_bids) {

  ## has the player received bids from multiple bidders?
  my @all_bidders = nsort @{$player_hash{$player}}; ## all bidders for player across all bids
  my @all_bidders_current = nsort keys %{$first_bids{$player}}; ## all bidders for player in 1st-round
  print STDERR "Player: '$player'; bidders: ".join(", ", @all_bidders_current)."\n" if ( $debug );

  if (scalar(@all_bidders) == 1) {
    ## if player has only 1 bidder && its a 1st-choice bid, they win straight away and bidder is removed from subsequent bidding rounds
    my $bidder = $all_bidders[0];
    $winner_of{$player}{bidder} = $bidder;
    $winner_of{$player}{bid_value} = $first_bids{$player}{$bidder}{1};
    $winner_of{$player}{bid_number} = 1;
    $winner_of{$player}{bid_round} = 1;

    ## delete subsequent bids from bidder who has already won someone
    foreach my $player (keys %second_bids) {
      foreach my $bidder (keys %{$second_bids{$player}}) {
        delete $second_bids{$player}{$bidder} if $bidder eq $all_bidders[0]; ## delete bidder
      }
      delete $second_bids{$player} if ( values %{$second_bids{$player}} == 0 ); ## also delete any player that consequently has irrelevant bids
    }
    foreach my $player (keys %third_bids) {
      foreach my $bidder (keys %{$third_bids{$player}}) {
        delete $third_bids{$player}{$bidder} if $bidder eq $all_bidders[0];
      }
      delete $third_bids{$player} if ( values %{$third_bids{$player}} == 0 ); ## also delete any player that consequently has irrelevant bids
    }

  } else {
    ## find the winner of each team based on 1st-round bids
    $winner_of{$player}{bidder} = "NA"; ## won by no one
    $winner_of{$player}{bid_value} = 0; ## set initial bid == 0

    foreach my $i (1..3) {
      foreach my $bidder (@all_bidders_current) {
        print STDERR " Round 1\.$i: $player; $bidder bids £$first_bids{$player}{$bidder}{$i}m\n" if ( $debug );

        ## if current bid beats current winning bid...
        if ( $first_bids{$player}{$bidder}{$i} > $winner_of{$player}{bid_value} ) {
          ## ...but you don't bid against yourself
          if ( $bidder ne $winner_of{$player}{bidder} ) {
            ## we have a new winner!
            print STDERR "  New winner! Bid £$first_bids{$player}{$bidder}{$i}m ($bidder) BEATS old bid £$winner_of{$player}{bid_value}m ($winner_of{$player}{bidder})\n" if ( $debug );
            $winner_of{$player}{bidder} = $bidder;
            $winner_of{$player}{bid_value} = $first_bids{$player}{$bidder}{$i};
            $winner_of{$player}{bid_number} = $i;
            $winner_of{$player}{bid_round} = 1;
          } else {
            print STDERR "  Bidder ($bidder) is same as current winner ($winner_of{$player}{bidder}); bid stays at £$winner_of{$player}{bid_value}m\n" if ( $debug );
          }
        }
      }
    }
  }
}
## get the winners of round 1:
foreach (keys %winner_of) {
  $winners_so_far{$winner_of{$_}{bidder}} = ();
}

print "\n[DEBUG] 1st-round winners: ".join(", ", nsort keys %winners_so_far)."\n" if ( $debug );
print Dumper (\%winner_of) if ( $debug );

unless ( $debug ) {
  print STDERR "[INFO] Sorting Round #2 bids...\n";
  sleep 1; #print STDERR "*";sleep 1; print STDERR "*";sleep 1; print STDERR "*"; sleep 1;
}

################################
## SECOND ROUND
################################
print STDERR "\n## SECOND-ROUND\n\n" if ( $debug );

foreach my $player (nsort keys %second_bids) {

  ## all bidders for player '$player' in 2nd-round
  my @all_bidders_current = nsort keys %{$second_bids{$player}};
  print STDERR "Player: '$player'; bidders: ".join(", ", @all_bidders_current)."\n" if ( $debug );

  ## if there is already a winning bid for $player from 1st-round bids...
  if ( $winner_of{$player}{bid_value} ) {
    print STDERR " Current winning bid for '$player' is £$winner_of{$player}{bid_value}m (\#$winner_of{$player}{bid_round}\.$winner_of{$player}{bid_number}: '$winner_of{$player}{bidder}')\n" if ( $debug );

    ## ... need to determine if anyone's 2nd-round bid beats it
    foreach my $i (1..3) { ## cycle thru 3 bids
      foreach my $bidder (@all_bidders_current) { ## cylye thru all bidders for $player
        print STDERR "  Round 2\.$i: $player; '$bidder' bids £$second_bids{$player}{$bidder}{$i}m\n" if ( $debug );
        unless ( grep /$bidder/, keys %winners_so_far ) { ## discount a winning bidder if they are ALREADY WINNING someone (higher preference)

          ## if current bid beats current winning bid ...
          if ( $second_bids{$player}{$bidder}{$i} > $winner_of{$player}{bid_value} ) {
            ## ... but you don't bid against yourself
            if ( $bidder ne $winner_of{$player}{bidder} ) {

              ## what is the bid_number of current winning bid?
              if ($winner_of{$player}{bid_number} == 3) {
                ## we have a new winner!
                print STDERR "   New winner! Bid £$second_bids{$player}{$bidder}{$i}m ('$bidder') BEATS old bid £$winner_of{$player}{bid_value}m ('$winner_of{$player}{bidder}')\n" if ( $debug );
                ## old winner needs to be removed from %winners_so_far so they are not discounted from future bids!
                delete $winners_so_far{$winner_of{$player}{bidder}}; ## delete BEFORE %winner_of inherits new $bidder!
                ## new winner populates %winner_of
                $winner_of{$player}{bidder} = $bidder;
                $winner_of{$player}{bid_value} = $second_bids{$player}{$bidder}{$i};
                $winner_of{$player}{bid_number} = $i;
                $winner_of{$player}{bid_round} = 2;

              } elsif ($winner_of{$player}{bid_number} == 2) {
                ## check if ith 2nd-round bid also beats top 1st round bid of current winner
                if ($first_bids{$player}{$winner_of{$player}{bidder}}{3} > $second_bids{$player}{$bidder}{$i}) {
                  ## winner stays but bid increases!
                  print STDERR "   Bidding war! Old bid \#1.3 £$first_bids{$player}{$winner_of{$player}{bidder}}{3}m ('$winner_of{$player}{bidder}') BEATS current bid £$second_bids{$player}{$bidder}{$i}m ('$bidder')\n" if ( $debug );
                  $winner_of{$player}{bid_value} = $first_bids{$player}{$winner_of{$player}{bidder}}{3};
                  $winner_of{$player}{bid_number} = 3;
                } else {
                  ## we have a new winner!
                  print STDERR "   New winner! Bid £$second_bids{$player}{$bidder}{$i}m ('$bidder') BEATS old bid £$winner_of{$player}{bid_value}m ('$winner_of{$player}{bidder}')\n" if ( $debug );
                  ## old winner needs to be removed from %winners_so_far so they are not discounted from future bids!
                  delete $winners_so_far{$winner_of{$player}{bidder}}; ## delete BEFORE %winner_of inherits new $bidder!
                  ## new winner populates %winner_of
                  $winner_of{$player}{bidder} = $bidder;
                  $winner_of{$player}{bid_value} = $second_bids{$player}{$bidder}{$i};
                  $winner_of{$player}{bid_number} = $i;
                  $winner_of{$player}{bid_round} = 2;
                }
              } elsif ($winner_of{$player}{bid_number} == 1) {
                ## check if ith 2nd-round bid also beats middle and top 1st round bid of current winner
                if ($first_bids{$player}{$winner_of{$player}{bidder}}{2} > $second_bids{$player}{$bidder}{$i}) {
                  ## winner stays but bid increases!
                  print STDERR "   Bidding war! Old bid \#1.2 £$first_bids{$player}{$winner_of{$player}{bidder}}{2}m ('$winner_of{$player}{bidder}') BEATS current bid £$second_bids{$player}{$bidder}{$i}m ('$bidder')\n" if ( $debug );
                  $winner_of{$player}{bid_value} = $first_bids{$player}{$winner_of{$player}{bidder}}{2};
                  $winner_of{$player}{bid_number} = 2;
                } elsif ($first_bids{$player}{$winner_of{$player}{bidder}}{3} > $second_bids{$player}{$bidder}{$i}) {
                  ## winner stays but bid increases!
                  print STDERR "   Bidding war! Old bid \#1.3 £$first_bids{$player}{$winner_of{$player}{bidder}}{3}m ('$winner_of{$player}{bidder}') BEATS current bid £$second_bids{$player}{$bidder}{$i}m ('$bidder')\n" if ( $debug );
                  $winner_of{$player}{bid_value} = $first_bids{$player}{$winner_of{$player}{bidder}}{3};
                  $winner_of{$player}{bid_number} = 3;
                } else {
                  ## we have a new winner!
                  print STDERR "   New winner! Bid £$second_bids{$player}{$bidder}{$i}m ('$bidder') BEATS old bid £$winner_of{$player}{bid_value}m ('$winner_of{$player}{bidder}')\n" if ( $debug );
                  ## old winner needs to be removed from %winners_so_far so they are not discounted from future bids!
                  delete $winners_so_far{$winner_of{$player}{bidder}}; ## delete BEFORE %winner_of inherits new $bidder!
                  ## new winner populates %winner_of
                  $winner_of{$player}{bidder} = $bidder;
                  $winner_of{$player}{bid_value} = $second_bids{$player}{$bidder}{$i};
                  $winner_of{$player}{bid_number} = $i;
                  $winner_of{$player}{bid_round} = 2;
                }
              }
            } else {
              print STDERR "   Bidder ($bidder) is same as current winner ($winner_of{$player}{bidder}); bid stays at £$winner_of{$player}{bid_value}m\n" if ( $debug );
            } ## end of bid vs self loop
          }
        } else {
          print STDERR "  Bidder ($bidder) is same as current winner ($winner_of{$player}{bidder}); bid stays at £$winner_of{$player}{bid_value}m\n" if ( $debug );
        }
      }
    }
  } else {
    print " No winning bid for '$player' from Round \#1...\n" if ( $debug );
    ## find the winner of each team based on 2nd-round bids
    $winner_of{$player}{bidder} = "NA"; ## won by no one
    $winner_of{$player}{bid_value} = 0; ## set initial bid == 0

    foreach my $i (1..3) {
      foreach my $bidder (@all_bidders_current) {
        print STDERR "  Round \#2\.$i: '$player'; '$bidder' bids £$second_bids{$player}{$bidder}{$i}m\n" if ( $debug );

        unless ( grep /$bidder/, keys %winners_so_far ) { ## discount a winning bidder if they are ALREADY WINNING someone (higher preference)
          ## if current bid beats current winning bid...
          if ( $second_bids{$player}{$bidder}{$i} > $winner_of{$player}{bid_value} ) {
            ## ...but you don't bid against yourself
            if ( $bidder ne $winner_of{$player}{bidder} ) {
              ## we have a new winner!
              print STDERR "   New winner! Bid £$second_bids{$player}{$bidder}{$i}m ('$bidder') BEATS old bid £$winner_of{$player}{bid_value}m ('$winner_of{$player}{bidder}')\n" if ( $debug );
              ## old winner needs to be removed from %winners_so_far so they are not discounted from future bids!
              delete $winners_so_far{$winner_of{$player}{bidder}}; ## delete BEFORE %winner_of inherits new $bidder!
              ## new winner populates %winner_of
              $winner_of{$player}{bidder} = $bidder;
              $winner_of{$player}{bid_value} = $second_bids{$player}{$bidder}{$i};
              $winner_of{$player}{bid_number} = $i;
              $winner_of{$player}{bid_round} = 2;
            } else {
              print STDERR "   Bidder ('$bidder') is same as current winner ('$winner_of{$player}{bidder}'); bid stays at £$winner_of{$player}{bid_value}m\n" if ( $debug );
            }
          }
        } else {
          print STDERR "   Bidder '$bidder' is already winning a player; bids discounted!\n" if ( $debug );
        }
      }
    }
  }
}
## add the winners of round 2:
foreach (keys %winner_of) {
  $winners_so_far{$winner_of{$_}{bidder}} = ();
}
print "\n[DEBUG] 2st-round winners: ".join(", ", nsort keys %winners_so_far)."\n" if ( $debug );
print Dumper (\%winner_of) if ( $debug );

unless ( $debug ) {
  print STDERR "[INFO] Sorting Round #3 bids...\n";
  sleep 1; #print STDERR "*";sleep 1; print STDERR "*";sleep 1; print STDERR "*"; sleep 1;
}

################################
## THIRD ROUND
################################
print STDERR "\n## THIRD-ROUND\n\n" if ( $debug );

foreach my $player (nsort keys %third_bids) {

  my @all_bidders_current = nsort keys %{$third_bids{$player}}; ## all bidders for player '$player' in 2nd-round
  print STDERR "Player: '$player'; bidders: ".join(", ", @all_bidders_current)."\n" if ( $debug );

  ## if there is already a winning bid for $player from 1st or 2nd-round bids...
  if ( $winner_of{$player}{bid_value} ) {
    print STDERR " Current winning bid for '$player' is £$winner_of{$player}{bid_value}m ('$winner_of{$player}{bidder}')\n" if ( $debug );

    foreach my $i (1..3) { ## cycle thru 3 bids
      foreach my $bidder (@all_bidders_current) { ## cylye thru all bidders for $player
        print STDERR "  Round \#3\.$i: '$player'; '$bidder' bids £$third_bids{$player}{$bidder}{$i}m\n" if ( $debug );
        unless ( grep /$bidder/, keys %winners_so_far ) { ## discount a winning bidder if they are ALREADY WINNING someone (higher preference)

          ## if current bid beats current winning bid ...
          if ( $third_bids{$player}{$bidder}{$i} > $winner_of{$player}{bid_value} ) {
            ## ... but you don't bid against yourself
            if ( $bidder ne $winner_of{$player}{bidder} ) {

              ## what is the bid_number of current winning bid?
              ## EVALUATE vs round #1 bids
              if ( ($winner_of{$player}{bid_round} == 1) && ($winner_of{$player}{bid_number} == 3) ) { ## round #1; 3rd bid
                ## we have a new winner!
                print STDERR "   New winner! Bid £$third_bids{$player}{$bidder}{$i}m ('$bidder') BEATS old bid £$winner_of{$player}{bid_value}m ('$winner_of{$player}{bidder}')\n" if ( $debug );
                ## old winner needs to be removed from %winners_so_far so they are not discounted from future bids!
                delete $winners_so_far{$winner_of{$player}{bidder}}; ## delete BEFORE %winner_of inherits new $bidder!
                ## new winner populates %winner_of
                $winner_of{$player}{bidder} = $bidder;
                $winner_of{$player}{bid_value} = $third_bids{$player}{$bidder}{$i};
                $winner_of{$player}{bid_number} = $i;
                $winner_of{$player}{bid_round} = 3;
              } elsif ( ($winner_of{$player}{bid_round} == 1) && ($winner_of{$player}{bid_number} == 2) ) { ## round #1; 2nd bid
                ## check if current bid also beats bid #1.2 of current winner
                if ($first_bids{$player}{$winner_of{$player}{bidder}}{3} > $third_bids{$player}{$bidder}{$i}) {
                  ## winner stays but bid increases!
                  print STDERR "   Bidding war! Old bid \#1.3 £$first_bids{$player}{$winner_of{$player}{bidder}}{3}m ('$winner_of{$player}{bidder}') BEATS current bid £$third_bids{$player}{$bidder}{$i}m ('$bidder')\n" if ( $debug );
                  $winner_of{$player}{bid_value} = $first_bids{$player}{$winner_of{$player}{bidder}}{3};
                  $winner_of{$player}{bid_number} = 3;
                } else {
                  ## we have a new winner!
                  print STDERR "   New winner! Bid £$third_bids{$player}{$bidder}{$i}m ('$bidder') BEATS old bid £$winner_of{$player}{bid_value}m ('$winner_of{$player}{bidder}')\n" if ( $debug );
                  ## old winner needs to be removed from %winners_so_far so they are not discounted from future bids!
                  delete $winners_so_far{$winner_of{$player}{bidder}}; ## delete BEFORE %winner_of inherits new $bidder!
                  ## new winner populates %winner_of
                  $winner_of{$player}{bidder} = $bidder;
                  $winner_of{$player}{bid_value} = $third_bids{$player}{$bidder}{$i};
                  $winner_of{$player}{bid_number} = $i;
                  $winner_of{$player}{bid_round} = 3;
                }
              } elsif ( ($winner_of{$player}{bid_round} == 1) && ($winner_of{$player}{bid_number} == 1) ) { ## round #1; 1st bid
                ## check if current bid also beats bids #1.2 and #1.3 of current winner
                if ($first_bids{$player}{$winner_of{$player}{bidder}}{2} > $third_bids{$player}{$bidder}{$i}) {
                  ## winner stays but bid increases!
                  print STDERR "   Bidding war! Old bid \#1.2 £$first_bids{$player}{$winner_of{$player}{bidder}}{2}m ('$winner_of{$player}{bidder}') BEATS current bid £$third_bids{$player}{$bidder}{$i}m ('$bidder')\n" if ( $debug );
                  $winner_of{$player}{bid_value} = $first_bids{$player}{$winner_of{$player}{bidder}}{2};
                  $winner_of{$player}{bid_number} = 2;
                } elsif ($first_bids{$player}{$winner_of{$player}{bidder}}{3} > $third_bids{$player}{$bidder}{$i}) {
                  ## winner stays but bid increases!
                  print STDERR "   Bidding war! Old bid \#1.3 £$first_bids{$player}{$winner_of{$player}{bidder}}{3}m ('$winner_of{$player}{bidder}') BEATS current bid £$third_bids{$player}{$bidder}{$i}m ('$bidder')\n" if ( $debug );
                  $winner_of{$player}{bid_value} = $first_bids{$player}{$winner_of{$player}{bidder}}{3};
                  $winner_of{$player}{bid_number} = 3;
                } else {
                  ## we have a new winner!
                  print STDERR "   New winner! Bid £$third_bids{$player}{$bidder}{$i}m ('$bidder') BEATS old bid £$winner_of{$player}{bid_value}m ('$winner_of{$player}{bidder}')\n" if ( $debug );
                  ## old winner needs to be removed from %winners_so_far so they are not discounted from future bids!
                  delete $winners_so_far{$winner_of{$player}{bidder}}; ## delete BEFORE %winner_of inherits new $bidder!
                  ## new winner populates %winner_of
                  $winner_of{$player}{bidder} = $bidder;
                  $winner_of{$player}{bid_value} = $third_bids{$player}{$bidder}{$i};
                  $winner_of{$player}{bid_number} = $i;
                  $winner_of{$player}{bid_round} = 3;
                }
              } ## end EVALUATE

              ## EVALUATE vs round #2 bids
              if ( ($winner_of{$player}{bid_round} == 2) && ($winner_of{$player}{bid_number} == 3) ) { ## round #1; 3rd bid
                ## we have a new winner!
                print STDERR "   New winner! Bid £$third_bids{$player}{$bidder}{$i}m ('$bidder') BEATS old bid £$winner_of{$player}{bid_value}m ('$winner_of{$player}{bidder}')\n" if ( $debug );
                ## old winner needs to be removed from %winners_so_far so they are not discounted from future bids!
                delete $winners_so_far{$winner_of{$player}{bidder}}; ## delete BEFORE %winner_of inherits new $bidder!
                ## new winner populates %winner_of
                $winner_of{$player}{bidder} = $bidder;
                $winner_of{$player}{bid_value} = $third_bids{$player}{$bidder}{$i};
                $winner_of{$player}{bid_number} = $i;
                $winner_of{$player}{bid_round} = 3;
              } elsif ( ($winner_of{$player}{bid_round} == 2) && ($winner_of{$player}{bid_number} == 2) ) { ## round #2; 2nd bid
                ## check if ith 2nd-round bid also beats top 1st round bid of current winner
                if ($second_bids{$player}{$winner_of{$player}{bidder}}{3} > $third_bids{$player}{$bidder}{$i}) {
                  ## winner stays but bid increases!
                  print STDERR "   Bidding war! Old bid \#2.3 £$second_bids{$player}{$winner_of{$player}{bidder}}{3}m ('$winner_of{$player}{bidder}') BEATS current bid £$third_bids{$player}{$bidder}{$i}m ('$bidder')\n" if ( $debug );
                  $winner_of{$player}{bid_value} = $second_bids{$player}{$winner_of{$player}{bidder}}{3};
                  $winner_of{$player}{bid_number} = 3;
                } else {
                  ## we have a new winner!
                  print STDERR "   New winner! Bid £$third_bids{$player}{$bidder}{$i}m ('$bidder') BEATS old bid £$winner_of{$player}{bid_value}m ('$winner_of{$player}{bidder}')\n" if ( $debug );
                  ## old winner needs to be removed from %winners_so_far so they are not discounted from future bids!
                  delete $winners_so_far{$winner_of{$player}{bidder}}; ## delete BEFORE %winner_of inherits new $bidder!
                  ## new winner populates %winner_of
                  $winner_of{$player}{bidder} = $bidder;
                  $winner_of{$player}{bid_value} = $third_bids{$player}{$bidder}{$i};
                  $winner_of{$player}{bid_number} = $i;
                  $winner_of{$player}{bid_round} = 3;
                }
              } elsif ( ($winner_of{$player}{bid_round} == 2) && ($winner_of{$player}{bid_number} == 1) ) { ## round #1; 1st bid
                ## check if current bid also beats bids #2.2 and #2.3 of current winner
                if ($second_bids{$player}{$winner_of{$player}{bidder}}{2} > $third_bids{$player}{$bidder}{$i}) {
                  ## winner stays but bid increases!
                  print STDERR "   Bidding war! Old bid \#2.2 £$second_bids{$player}{$winner_of{$player}{bidder}}{2}m ('$winner_of{$player}{bidder}') BEATS current bid £$third_bids{$player}{$bidder}{$i}m ('$bidder')\n" if ( $debug );
                  $winner_of{$player}{bid_value} = $second_bids{$player}{$winner_of{$player}{bidder}}{2};
                  $winner_of{$player}{bid_number} = 2;
                } elsif ($second_bids{$player}{$winner_of{$player}{bidder}}{3} > $third_bids{$player}{$bidder}{$i}) {
                  ## winner stays but bid increases!
                  print STDERR "   Bidding war! Old bid \#2.3 £$second_bids{$player}{$winner_of{$player}{bidder}}{3}m ('$winner_of{$player}{bidder}') BEATS current bid £$third_bids{$player}{$bidder}{$i}m ('$bidder')\n" if ( $debug );
                  $winner_of{$player}{bid_value} = $second_bids{$player}{$winner_of{$player}{bidder}}{3};
                  $winner_of{$player}{bid_number} = 3;
                } else {
                  ## we have a new winner!
                  print STDERR "   New winner! Bid £$third_bids{$player}{$bidder}{$i}m ('$bidder') BEATS old bid £$winner_of{$player}{bid_value}m ('$winner_of{$player}{bidder}')\n" if ( $debug );
                  ## old winner needs to be removed from %winners_so_far so they are not discounted from future bids!
                  delete $winners_so_far{$winner_of{$player}{bidder}}; ## delete BEFORE %winner_of inherits new $bidder!
                  ## new winner populates %winner_of
                  $winner_of{$player}{bidder} = $bidder;
                  $winner_of{$player}{bid_value} = $third_bids{$player}{$bidder}{$i};
                  $winner_of{$player}{bid_number} = $i;
                  $winner_of{$player}{bid_round} = 3;
                }
              } ## end EVALUATE
            }
          }
        } else {
          print STDERR "   Bidder '$bidder' is already winning a player; bids discounted!\n" if ( $debug );
        }
      }
    }
  } else {
    print " No winning bid for '$player' from Rounds \#1 or \#2...\n" if ( $debug );
    ## find the winner of each team based on 2nd-round bids
    $winner_of{$player}{bidder} = "NA"; ## won by no one
    $winner_of{$player}{bid_value} = 0; ## set initial bid == 0

    foreach my $i (1..3) {
      foreach my $bidder (@all_bidders_current) {
        print STDERR "  Round \#3\.$i: '$player'; '$bidder' bids £$third_bids{$player}{$bidder}{$i}m\n" if ( $debug );

        unless ( grep /$bidder/, keys %winners_so_far ) {
          ## if current bid beats current winning bid...
          if ( $third_bids{$player}{$bidder}{$i} > $winner_of{$player}{bid_value} ) {
            ## ...but you don't bid against yourself
            if ( $bidder ne $winner_of{$player}{bidder} ) {
              ## we have a new winner!
              print STDERR "   New winner! Bid £$third_bids{$player}{$bidder}{$i}m ('$bidder') BEATS old bid £$winner_of{$player}{bid_value}m ('$winner_of{$player}{bidder}')\n" if ( $debug );
              ## old winner needs to be removed from %winners_so_far so they are not discounted from future bids!
              delete $winners_so_far{$winner_of{$player}{bidder}}; ## delete BEFORE %winner_of inherits new $bidder!
              ## new winner populates %winner_of
              $winner_of{$player}{bidder} = $bidder;
              $winner_of{$player}{bid_value} = $third_bids{$player}{$bidder}{$i};
              $winner_of{$player}{bid_number} = $i;
              $winner_of{$player}{bid_round} = 3;
            } else {
              print STDERR "   Bidder ('$bidder') is same as current winner ('$winner_of{$player}{bidder}'); bid stays at £$winner_of{$player}{bid_value}m\n" if ( $debug );
            }
          }
        } else {
          print STDERR "   Bidder '$bidder' is already winning a player; bids discounted!\n" if ( $debug );
        }
      }
    }
  }
}
print STDERR "\n[DEBUG] 3rd-round winners: ".join(", ", nsort keys %winners_so_far)."\n" if ( $debug );
print STDERR Dumper (\%winner_of) if ( $debug );

print "\n";
print '
 ___       __   ___  ________   ________   _______   ________  ________  ___
|\  \     |\  \|\  \|\   ___  \|\   ___  \|\  ___ \ |\   __  \|\   ____\|\  \
\ \  \    \ \  \ \  \ \  \\\ \  \ \  \\\ \  \ \   __/|\ \  \|\  \ \  \___|\ \  \
 \ \  \  __\ \  \ \  \ \  \\\ \  \ \  \\\ \  \ \  \_|/_\ \   _  _\ \_____  \ \  \
  \ \  \|\__\_\  \ \  \ \  \\\ \  \ \  \\\ \  \ \  \_|\ \ \  \\\  \\\|____|\  \ \__\
   \ \____________\ \__\ \__\\\ \__\ \__\\\ \__\ \_______\ \__\\\ _\ ____\_\  \|__|
    \|____________|\|__|\|__| \|__|\|__| \|__|\|_______|\|__|\|__|\_________\  ___
                                                                 \|_________| |\__\
                                                                              \|__|';
print "\n";
sleep 2;

foreach (sort {$winner_of{$b}{bid_value} <=> $winner_of{$a}{bid_value}} keys %winner_of) {
  unless ($winner_of{$_}{bidder} eq "NA") {
    print STDERR "***\n";
    print STDERR "$_ ";
    sleep 1;
    print STDERR "--> $winner_of{$_}{bidder} (£$winner_of{$_}{bid_value}m)\n";
    sleep 1;
  }
}
print "***\n";
print "\nFinished ".`date`."\n";
print "FUCKIN' ATODASO!\n\n";
