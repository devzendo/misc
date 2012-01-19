#
# bayes.pl - a Bayesian filter for TTYtter, useful for getting rid of things you
# don't want to see, and highighting things you do. Not necessarily spam/ham
# detection.
#
# Commands:
# /spam id id id .. id (or /- id id id .. id)  Learns tweets that are lower priority
# /ham id id id .. id (or /+ id id id .. id)   Learns tweets that are higher priority
#
# (C) 2012 Matt J. Gumbley http://devzendo.org @mattgumbley
# Distributed under the Apache License, v2.0.
#
# usage: ttytter.pl -exts=bayes.pl -readline
# (Use of -readline and Term::Readline::TTYtter highly recommended)
#
use Data::Dumper;
use Algorithm::Bayesian;

$store->{bayes_storage_file} = "$ENV{'HOME'}/.ttytter_bayes.data";
$store->{bayes_storage} = undef;

if (-e $store->{bayes_storage_file}) {
        $store->{bayes_storage} = bayes_load();
} else {
        $store->{bayes_storage} = bayes_save({});
}

$store->{bayes_classifier} = Algorithm::Bayesian->new($store->{bayes_storage});

$handle = sub {
        my $ref = shift;
        $ref->{'priority'} = 'default';
        my @words = @{bayes_filter_content($ref->{'text'})};
        my $spamPr = 0.5;
        if (@words) {
                $spamPr = $store->{bayes_classifier}->test(@words);
                if ($spamPr < 0.33) {
                        $ref->{'priority'} = 'high';
                } elsif ($spamPr > 0.66) {
                        $ref->{'priority'} = 'low';
                }
        }
        $ref->{'spam_probability'} = $spamPr;
        return defaulthandle($ref);
};


$addaction = sub {
	my $command = shift;
	if ($command =~ s#^/(spam|\-) ?## && length($command)) {
                my @tweets = @{bayes_tweets_from_ids($command)};
                foreach (@tweets) {
                        bayes_mark_spam($_);
                }
                bayes_save($store->{bayes_storage});
                return 1;
        } elsif ($command =~ s#^/(ham|\+) ?## && length($command)) {
                my @tweets = @{bayes_tweets_from_ids($command)};
                foreach (@tweets) {
                        bayes_mark_ham($_);
                }
                bayes_save($store->{bayes_storage});
                return 1;
        } else {
                return 0;
        }
};

sub bayes_tweets_from_ids {
        my $id_spec = shift;
        my @tweets = ();
        my @id_list = split(' ', $id_spec);
        foreach (@id_list) {
	        my $tweet = &get_tweet($_);
		if (!$tweet->{'id_str'}) {
                        print $stdout "-- sorry, no such tweet $_ (yet?).\n";
                } else {
                        push @tweets, $tweet;
                }
        }
        return \@tweets;
}

sub bayes_load {
        open(my $fh, '<', $store->{bayes_storage_file}) or die "Cannot open $store->{bayes_storage_file}: $!\n";
        my $VAR1 = undef;
        eval(join('', (<$fh>)));
        close $fh;
        return $VAR1;
}

sub bayes_save {
        my $data = shift;
        open(my $fh, '>', $store->{bayes_storage_file}) or die "Cannot create $store->{bayes_storage_file}: $!\n";
        print $fh Dumper($data);
        close $fh;
        return $data;
}

sub bayes_filter_content {
        my $text = shift;
        my @in = split(/ /, $text);
        my @out = ();
        foreach (@in) {
                next if /(RT|http:|\@\w+)/;
                # delete all punctuation except # in hashtags
                $_ = join('', map { if ($_ eq '#') { $_ } else { $_ =~ s/[[:punct:]]//g; $_ } } split(//, $_));
                next if /^\s*$/;
                push @out, $_;
        }
        return \@out;
}

sub bayes_mark_spam {
        my $ref = shift;
        my @words = @{bayes_filter_content($ref->{text})};
        print $stdout "-- SPAM: $_->{menu_select} @words\n";
        if (@words) {
                $store->{bayes_classifier}->spam(@words);
        }
}

sub bayes_mark_ham {
        my $ref = shift;
        my @words = @{bayes_filter_content($ref->{text})};
        print $stdout "-- HAM:  $_->{menu_select} @words\n";
        if (@words) {
                $store->{bayes_classifier}->ham(@words);
        }
}

1;
