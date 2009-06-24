# CustomFields::XMLRPCServerの改造版
#
# CustomFields::XMLRPCServerは、カスタムフィールドをXMLRPCで送信する際、改行コードをデリミタとしているため、
# 値自体に改行が入っている場合に正常に処理できない。そのため、本モジュールでは、値に対するURLエンコードを必須とし、本モジュール内でURLデコード処理を
# 行う事で改行の問題が起こらないように対応。
#
# 本モジュールを呼び出すためには、/cgi-bin/mt/addons/Commercial.pack/config.yaml 内を以下のように修正する。
#
# #26行目付近
# #api_post_save.entry: $Commercial::CustomFields::XMLRPCServer::APIPostSave_entry
# api_post_save.entry: $MLXEditorHelper::MLXEditorHelper::XMLRPCServer::APIPostSave_entry
#

package MLXEditorHelper::XMLRPCServer;

use strict;
use CustomFields::Util qw( get_meta save_meta );
use URI::Escape;

sub APIPostSave_entry {
    my ($cb, $mt, $entry, $original) = @_;

		MT::Plugin::MLXEditorHelper::doLog("use xmlrpc. entry_id: " . $entry->id);

    require MT::XMLRPCServer;

    # The following has been mostly copied from the KeyValues plugin
    # by Brad Choate <http://bradchoate.com/weblog/2002/07/27/keyvalues>
    # licensed under the MIT License <http://www.opensource.org/licenses/mit-license.php>

    my $delimiter = '=';

    my $t = $entry->text_more;
    $t = '' unless defined $t;

    my (%values, @stripped, $need_closure, $line);

    my @lines = split /\r?\n/, $t;
    my $row = 0;
    my $count = scalar(@lines);
    while ($row < $count) {
        $line = $lines[$row];
        chomp $line;
        if ($line =~ m/^[A-Z0-9][^\s]+?$delimiter/io) {
            # key/value!
            my ($key, $value) = $line =~ m/^([A-Z0-9][^\s]+?)$delimiter(.*)/io;
            if ($value eq $delimiter) {
                $value = ''; # discard opening delimiter
                # read additional lines until we find '$delimiter$key'
                $row++;
                $need_closure = $key;
                while ($row < $count) {
                    $line = $lines[$row];
                    chomp $line;
                    if ($line =~ m/^$delimiter$delimiter$key\s*$/) {
                        undef $need_closure;
                        last;
                    } else {
                        $value .= $line . "\n";
                    }
                    $row++;
                }
                chomp $value if $value;
            }

						# edit okitsu 2009/06/17
            #$values{$key} = $value;
            $values{$key} = uri_unescape($value);
        } else {
            push @stripped, $line;
        }
        $row++;
    }
    if ($need_closure) {
        die MT::XMLRPCServer::_fault("Key $need_closure was not closed properly: missing '$delimiter$delimiter$need_closure'");
    }
    $t = join "\n", @stripped;
    $t = '' unless defined $t;

    $entry->text_more($t);
    $entry->save or die MT::XMLRPCServer::_fault($entry->errstr);

    my $meta = get_meta($entry);
    foreach my $key (keys %values) {
        $meta->{$key} = $values{$key};
    }
    save_meta($entry, $meta);
}

1;
