package CopyToProductionHelper::L10N::ja;

use strict;
use base 'CopyToProductionHelper::L10N';
use vars qw( %Lexicon );

our %Lexicon = (
		'CopyToProductionHelper' => 'CopyToProduction Helper',
    'PLUGIN_DESCRIPTION' => 'MT運用ををサポートする機能を提供します。',
    'TagTemplate' => 'タグテンプレート',
		'BodyImgTag' => '本文内imgタグ',
		'LinkImgTag' => 'リンクタグ',
		'This entry have been deployed.' => '本番環境へのデプロイが成功しました。',
		'An error occurred while trying to recover your deployed entry.' => '本番環境へのデプロイが失敗しました。ログを確認してください。',
		'deploy-to-production' => '本番環境へのデプロイ',		
);
1;
