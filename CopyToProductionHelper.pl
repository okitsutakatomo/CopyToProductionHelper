#########################################################
# Changes:
# 0.01 -- 新規作成
# 1.00 -- CMS.pmを削除し、MLXEditorHelper.plに処理を統合
#         CustomField::XMLRPCServer.pmをコピーし、カスタムフィールドをURLエンコード処理必須に変更
#         PluginSettingsを追加
# 1.10 -- カスタムフィールドすべての値に対応したことで、すべてのブログに対応。
#         

package MT::Plugin::MLXEditorHelper;
use strict;
use MT;
use MT::Plugin;
use CustomFields::Util qw( get_meta save_meta );
use XMLRPC::Lite;
use Data::Dumper;
use MT::Entry;
use MT::ObjectTag;
use MT::Tag;
use URI::Escape;
use URI;

our $VERSION = '1.10';

use base qw( MT::Plugin );

@MT::Plugin::MLXEditorHelper::ISA = qw( MT::Plugin );

my $plugin = new MT::Plugin::MLXEditorHelper ( {
    name => '<MT_TRANS phrase="MLXEditorHelper">',
    id   => 'MLXEditorHelper',
    key  => __PACKAGE__,
    description => '<MT_TRANS phrase="PLUGIN_DESCRIPTION">',
    author_name => 'Takatomo Okitsu',
    author_link => 'http://moonlinx.jp',
    version     => $VERSION,
    settings => new MT::PluginSettings ( [
        ['xmlrpc_url', { Default => 'http://moonlinx.jp/cgi-bin/mt/mt-xmlrpc.cgi', Scope => 'system' }],
        ['xmlrpc_username', { Default => 'moonlinx', Scope => 'system' }],
        ['xmlrpc_password', { Default => 'yasuda20007', Scope => 'system' }],
        ['mtcgi_url', { Default => 'http://moonlinx.jp/cgi-bin/mt/mt.cgi', Scope => 'system' }],
        ['img_server_url', { Default => 'http://images.moonlinx.jp/images/entry/', Scope => 'system' }],
        ['tag_tmpl1', { Default => '<img src="http://images.moonlinx.jp/images/entry/XXXX.jpg" alt=""/>', Scope => 'system' }],
        ['tag_tmpl2', { Default => '<a href="XXXX" target="_blank">XXXX</a>', Scope => 'system' }],
        ['tag_tmpl3', { Default => '<span style="font-size: 10px">XXXX</span>', Scope => 'system' }],
        ['tag_tmpl4', { Default => '', Scope => 'system' }],
        ['tag_tmpl5', { Default => '', Scope => 'system' }],
        ['tag_tmpl6', { Default => '', Scope => 'system' }],
        ['tag_tmpl7', { Default => '', Scope => 'system' }],
        ['tag_tmpl8', { Default => '', Scope => 'system' }],
        ['tag_tmpl9', { Default => '', Scope => 'system' }],
        ['tag_tmpl10', { Default => '', Scope => 'system' }],
    ] ),
		system_config_template => \&config_template,
    l10n_class => 'MLXEditorHelper::L10N',
} );

MT->add_plugin( $plugin );

sub instance {
	return $plugin;
}

sub init_registry {
    my $plugin = shift;
    $plugin->registry( {
				applications => {
					cms => {
						methods => {
							deploy_to_production =>
								\&_deploy_to_production,
								#'$MLXEditorHelper::MLXEditorHelper::CMS::_deploy_to_production',
						},
          },
				},
        callbacks => {
            'MT::App::CMS::template_param.edit_entry'
                => \&_template_tag_area_param,
		        'MT::App::CMS::template_output.header'
		        		=> \&_jquery_to_header,
				    'MT::App::CMS::template_source.edit_entry'
								=> \&_message_edit,
						'api_pre_save.entry'
								=> \&_set_entry_hold,
        },
   } );
}

sub _deploy_to_production {
	my $app = shift;
  my (%param) = @_;

  my $blog_id = $app->param('blog_id');
	my $id = $app->param("id");
	
	#エントリの値を取得
	my $entry = MT::Entry->load({ id => $id });
	my $meta = get_meta($entry);	
	
	my $title = $entry->title;
	my $description = $entry->text;
	my $excerpt = $entry->excerpt;
#	my $entry_home_thumb = uri_escape($meta->{entry_home_thumb});
#	my $entry_thumb01 = uri_escape($meta->{entry_thumb01});
#	my $infocolumnbody = uri_escape($meta->{infocolumnbody});
#	my $entry_thumb_name = uri_escape($meta->{entry_thumb_name});	
#	my $datesofevent = uri_escape($meta->{datesofevent});
#	my $mt_text_more =<<TEXT;
#entry_thumb_name=$entry_thumb_name
#entry_home_thumb=$entry_home_thumb
#entry_thumb01=$entry_thumb01
#datesofevent=$datesofevent
#infocolumnbody=$infocolumnbody
#TEXT

	my $mt_text_more;
	my ($key, $value);
	while ( ($key, $value) = each(%$meta) ) {
		my $value = uri_escape($value);
		$mt_text_more .= "$key=$value\n";
	}

	#タグの取得
	my @tags = MT::Tag->load(undef, {
    	'join' => [ 'MT::ObjectTag', 'tag_id',
        	{ object_id => $entry->id }]
	});

	my @tags_name_array = ();
	my $i;
	for( $i=0 ; $i <= $#tags ; $i++ ){
		$tags_name_array[$i] = $tags[$i]->name;
	}
	
	$" = ',';
	my $tags_string = "@tags_name_array";

	
	#カテゴリIDの取得
	my $place = MT::Placement->load({ entry_id => $id });
	my $category_id;
	if($place){
		$category_id = $place->category_id;		
	}
	
	#エントリの投稿（レスポンスは投稿されたエントリのID）
	my $proxyurl = $plugin->get_setting('xmlrpc_url', $blog_id);
	my $username = $plugin->get_setting('xmlrpc_username', $blog_id);
	my $password = $plugin->get_setting('xmlrpc_password', $blog_id);
	my $new_entry_id = XMLRPC::Lite
	    -> proxy($proxyurl)
	    -> call('metaWeblog.newPost',
	            $entry->blog_id, # blog ID
	            $username, # Username
	            $password, # Web API Password
	            {
	                title => $entry->title, # Article title
	                description => $entry->text, # Entry body
									mt_excerpt => $entry->excerpt, # Entry excerpt
									mt_text_more => $mt_text_more,
									mt_tags => $tags_string,
	            },
	            0 # 再構築しない
	        )
	    -> result;
	if (defined ($new_entry_id)) { 
		#カテゴリの投稿
		#@see http://www.sixapart.com/developers/xmlrpc/movable_type_api/mtsetpostcategories.html
		my $res = XMLRPC::Lite 
		   -> proxy($proxyurl) 
		   -> call('mt.setPostCategories',
								$new_entry_id,
								$username,
								$password, 
		          	[
									{categoryId => $category_id}
								]
							) 
				->result;
		
			$param{deployed_object} = "1";
	} else { 
	  doLog("failed: $!"); 
	  $param{deployed_object} = "2";
	}

	#参照ページへリダイレクト
  $param{blog_id} = $blog_id if $blog_id;
  $param{id} = $id if $id;
  $param{_type} = "entry";
  #$param{deployed_object} = "1";
  return $app->redirect(
      $app->uri( mode => 'view', args => \%param ) );	
}


sub _template_tag_area_param {
  my ( $cb, $app, $param, $tmpl ) = @_;
  my $innerHTML;

#  $innerHTML .= _img_tag_tmpl();
#  $innerHTML .= _link_tag_tmpl();
	
	$innerHTML .= _tag_tmpls();

	my $widget = $tmpl->createElement( 'app:widget', { id => 'tagtemplate-widget',
                                                   label => $plugin->translate( 'TagTemplate' ),
                                                   required => 0,
                                                 }
                                 );
	$widget->innerHTML( $innerHTML );		

  my $pointer_field = $tmpl->getElementById( 'entry-publishing-widget' );
  $tmpl->insertBefore( $widget, $pointer_field );

	#widget2の設定
  my $tmpl_id = $app->param( 'id' );
  my $blog_id = $app->param( 'blog_id' );
	if($tmpl_id && $blog_id){
			my $uri = URI->new($plugin->get_setting('xmlrpc_url', $blog_id));
		  my $server = $uri->host;
			my $innerHTML2 = <<HTML;
			<input id="deploy_to_production_button" type="button" value="本番環境へ未公開でデプロイする">
			<div class="hint">本番環境($server)へ記事を未公開でコピーします。デプロイ対象となる記事は、必ず一旦保存されている必要があります。</div>
			<br />
			<div class="hint">2009/6/19: <span style="color: red">Staff's Voice以外</a>対応しました。</div>			
			<script type="text/javascript">
			\$(document).ready(function(){
				\$('#deploy_to_production_button').each(function() {
					\$('#deploy_to_production_button').click(function(){
						if(confirm('本番環境($server)へデプロイします。よろしいですか？')){
							location='<\$mt:var name="script_url"\$>?__mode=deploy_to_production&_type=entry&id=<\$mt:var name="id"\$>&blog_id=<\$mt:var name="blog_id"\$>';		
						}
					});
				});
			});
			</script>			
			<br />
HTML

			my $widget2 = $tmpl->createElement( 'app:widget', { id => 'deploy-to-production-widget',
		                                                 	label => $plugin->translate( 'deploy-to-production' ),
		                                                 	required => 0,
		                                               	}
																			);																	
		  $widget2->innerHTML($innerHTML2);

		  my $pointer_field = $tmpl->getElementById( 'entry-publishing-widget' );
		  $tmpl->insertAfter( $widget2, $pointer_field );		
	}
}


#################################### tag template start #####################################
#my $body_img_tag = <<EOT;
#&lt;span&gt;&lt;img src=&quot;@{[ $plugin->get_setting("img_server_url") ]}XXXX.jpg&quot; alt=&quot;XXXX.jpg&quot;/&gt;&lt;/span&gt;
#EOT
#
#my $link_tag = <<EOT;
#&lt;a href=&quot;http://XXXX&quot; target=&quot;_blank&quot; &gt;XXXX&lt;/a&gt;
#EOT
#################################### tag template end #####################################

sub _tag_tmpls {
	#my $blog_id = $app->param('blog_id');	
	
	my $tags;
	my $i;
	for ($i = 1; $i <= 5; $i++) {
	    my $tag_tmpl = $plugin->get_setting("tag_tmpl$i");
			if($tag_tmpl){
					    my $tag = <<TMPL;
									<mt:var name="mlx_tag_tmpl$i" value="$tag_tmpl">
					        <mtapp:setting
					            id="mlx_tag_tmpl$i"
					            label="テンプレ$i">
											<input id="mlx_tag_tmpl$i-input" type="text" value="<mt:var name="mlx_tag_tmpl$i" escape="html">"/>
											<script type="text/javascript">
											\$(document).ready(function(){
												\$('#mlx_tag_tmpl$i-input').each(function() {
													\$('#mlx_tag_tmpl$i-input').click(function(){
														\$(this).select();
													}).focus(function(){
														\$(this).select();
													});
												});
											});
											</script>
					        </mtapp:setting>
TMPL
			$tags .= $tag;				
			}
	}
	return $tags;
}


sub _jquery_to_header {
    my ( $cb, $app, $tmpl ) = @_;
    if (
         !( $app->param( '_type' ) eq 'entry' ) &&
         !( $app->param( '_type' ) eq 'page' ) &&
         !( $app->param( '_type' ) eq 'template' )
    ) {
        return 1;
    }
    my $head_etc =<<'HEAD';
<script src="http://ajax.googleapis.com/ajax/libs/jquery/1.3.1/jquery.min.js" type="text/javascript"></script>
<script type="text/javascript">
$(document).ready(function(){
	$('#customfield_entry_thumb_name').each(function() {
		$('#customfield_entry_thumb_name').keyup(function(){
			copy_to_input_url_box();
		});
		$('#customfield_entry_thumb_name').blur(function(){
			var current_value = $('#customfield_entry_thumb_name').val().trim();
			if(current_value != null && current_value.length > 0){
				copy_to_input_url_box();					
			}				
		});			
	});
});

function copy_to_input_url_box(){
	var base_url = "http://images.moonlinx.jp/images/entry/";
	var current_value = $('#customfield_entry_thumb_name').val().trim();
	var thumb_url = base_url + current_value + "-thumb02.jpg";
	var top_url = base_url + current_value + "-thumb01.jpg";
	$('#customfield_entry_home_thumb').val(top_url);
	$('#customfield_entry_thumb01').val(thumb_url);
}
</script>
HEAD
    $$tmpl =~ s/(<\/head>)/$head_etc$1/;
}

sub _message_edit{
	    my ($cb, $app, $tmpl) = @_;
			my $status = $app->param('deployed_object');
		  my $blog_id = $app->param('blog_id');			
			my $mtcgi_url = URI->new($plugin->get_setting('mtcgi_url', $blog_id));			
			my $slug;
			if ($status){
							if ($status == 1) {
								$slug = <<END_TMPL;
								      		<mtapp:statusmsg
								          		id="deployed_object"
								          		class="success">
															本番環境へのデプロイが成功しました。
								          		<a href="$mtcgi_url" target="_blank">本番環境を見る</a>
								      		</mtapp:statusmsg>
END_TMPL

							} elsif ($status == 2){
								$slug = <<END_TMPL;
									      		<mtapp:statusmsg
									          		id="deployed_object_errors"
									          		class="error">
									          		本番環境へのデプロイが失敗しました。入力項目に不足がないか確認してください。
									      		</mtapp:statusmsg>
END_TMPL
							}
				
			}
	    $$tmpl =~ s{(<div id="msg-block">)}{$1$slug}msg;
}

#XML-RPCで投稿した場合に、強制的に未公開にするための処理
#@see http://www.movabletype.jp/documentation/appendices/config-directives/nopublishmeansdraft.html
#@see http://okamot.com/mt/archives/2008/03/movabletype4x-x.html
sub _set_entry_hold {
	my ($cb, $app, $obj, $original) = @_;
	$obj->status(MT::Entry::HOLD());
}

sub get_setting {
	my $plugin = shift;
	my ($value, $blog_id) = @_;
	my %plugin_params;

	$plugin->load_config(\%plugin_params, 'blog:' . $blog_id);
	my $val = $plugin_params{$value};
	unless ($val) {
		$plugin->load_config(\%plugin_params, 'system');
		$val = $plugin_params{$value};
	}
 return $val;
}

sub config_template {
	my $tmpl = <<EOT
  <mtapp:setting
      id="xmlrpc_url"
      label="本番環境のXMLRPCインタフェースのURL">
			<input id="xmlrpc_url" type="text" name="xmlrpc_url" value="<mt:var name="xmlrpc_url" escape="html">"/>
  </mtapp:setting>
  <mtapp:setting
      id="xmlrpc_username"
      label="XMLRPCインタフェースのユーザID">
			<input id="xmlrpc_username" type="text" name="xmlrpc_username" value="<mt:var name="xmlrpc_username" escape="html">"/>
  </mtapp:setting>
  <mtapp:setting
      id="xmlrpc_password"
      label="XMLRPCインタフェースのパスワード">
			<input id="xmlrpc_password" type="password" name="xmlrpc_password" value="<mt:var name="xmlrpc_password" escape="html">"/>
  </mtapp:setting>
  <mtapp:setting
      id="mtcgi_url"
      label="本番環境のmt.cgiのURL">
			<input id="mtcgi_url" type="text" name="mtcgi_url" value="<mt:var name="mtcgi_url" escape="html">"/>
  </mtapp:setting>	
  <mtapp:setting
      id="img_server_url"
      label="イメージサーバのURL">
			<input id="img_server_url" type="text" name="img_server_url" value="<mt:var name="img_server_url" escape="html">"/>
  </mtapp:setting>
  <mtapp:setting
      id="tag_tmpl1"
      label="タグテンプレ1">
			<input id="tag_tmpl1" type="text" name="tag_tmpl1" value="<mt:var name="tag_tmpl1" escape="html">"/>
  </mtapp:setting>
  <mtapp:setting
      id="tag_tmpl2"
      label="タグテンプレ2">
			<input id="tag_tmpl2" type="text" name="tag_tmpl2" value="<mt:var name="tag_tmpl2" escape="html">"/>
  </mtapp:setting>
  <mtapp:setting
      id="tag_tmpl3"
      label="タグテンプレ3">
			<input id="tag_tmpl3" type="text" name="tag_tmpl3" value="<mt:var name="tag_tmpl3" escape="html">"/>
  </mtapp:setting>
  <mtapp:setting
      id="tag_tmpl4"
      label="タグテンプレ4">
			<input id="tag_tmpl4" type="text" name="tag_tmpl4" value="<mt:var name="tag_tmpl4" escape="html">"/>
  </mtapp:setting>
  <mtapp:setting
      id="tag_tmpl5"
      label="タグテンプレ5">
			<input id="tag_tmpl5" type="text" name="tag_tmpl5" value="<mt:var name="tag_tmpl5" escape="html">"/>
  </mtapp:setting>
  <mtapp:setting
      id="tag_tmpl6"
      label="タグテンプレ6">
			<input id="tag_tmpl6" type="text" name="tag_tmpl6" value="<mt:var name="tag_tmpl6" escape="html">"/>
  </mtapp:setting>
  <mtapp:setting
      id="tag_tmpl7"
      label="タグテンプレ7">
			<input id="tag_tmpl7" type="text" name="tag_tmpl7" value="<mt:var name="tag_tmpl7" escape="html">"/>
  </mtapp:setting>
  <mtapp:setting
      id="tag_tmpl8"
      label="タグテンプレ8">
			<input id="tag_tmpl8" type="text" name="tag_tmpl8" value="<mt:var name="tag_tmpl8" escape="html">"/>
  </mtapp:setting>
  <mtapp:setting
      id="tag_tmpl9"
      label="タグテンプレ9">
			<input id="tag_tmpl9" type="text" name="tag_tmpl9" value="<mt:var name="tag_tmpl9" escape="html">"/>
  </mtapp:setting>
  <mtapp:setting
      id="tag_tmpl10"
      label="タグテンプレ10">
			<input id="tag_tmpl10" type="text" name="tag_tmpl10" value="<mt:var name="tag_tmpl10" escape="html">"/>
  </mtapp:setting>
EOT
}


sub doLog {
    my ($msg) = @_; 
    return unless defined($msg);

    use MT::Log;
    my $log = MT::Log->new;
    $log->message($msg) ;
    $log->save or die $log->errstr;
}
1;
