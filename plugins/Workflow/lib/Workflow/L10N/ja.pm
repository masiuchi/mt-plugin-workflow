package Workflow::L10N::ja;
use strict;
use warnings;
use base qw( Workflow::L10N );

our %Lexicon = (
    # workflow.pl
    'Workflow can limit publishing rights to editors, can limit specified authors to posting only drafts, and lets an author pass ownership of an entry to any other author or editor with appropriate permissions. Authors are notified when ownership of an entry is transferred.' => 'ワークフロープラグインはユーザーの公開権限を制限することができます。具体的には、ユーザーに対して下書きしか作成できないように制限して、公開権限を持つユーザーに記事所有者を変更する機能を使って、複数人で記事を公開します。記事の所有者を変更した場合、通知メールを送信する機能もあります。',
    'Workflow' => 'ワークフロー',
    'Workflow Transfer Notification' => 'ワークフローの承認依頼通知',
    'Error saving transferred entry: [_1]' => '記事の承認依頼途中でエラーが発生しました: [_1]',
    "Entry #[_1] transferred from '[_2]' to '[_3]' by '[_4]'" => "'[_4]' が記事 #[_1] について、'[_3]' に承認依頼を出しました。（記事の旧オーナー: [_3]）",
    'Entry cannot be transfered' => '記事の承認依頼を出すことができません。',
    "[_1] #[_2] transferred to [_3]" => '[_1] #[_2] について、[_3] に承認依頼を出しました。',
    'Entry Transferred: [_1]' => '記事を承認依頼に出しました: [_1]',
    'Error sending transfer notification email to [_1]' => '[_1] への承認依頼メール送信時に、エラーが発生しました',
    'View audit log' => '承認履歴を見る',

    # tmpl/list_workflow_step.tmpl
    'Edit Workflow' => 'ワークフローの管理',
    'Save Order' => '承認ステップ順序の保存',
    'Create [_1] at the end' => '[_1]の作成',
    'Step' => '承認ステップ',
    'Steps' => '承認ステップ',

    # tmpl/edit_workflow_step.tmpl
    'Edit Workflow Step' => '承認ステップの編集',

    # lib/Workflow/CMS.pm
    'Change Note' => 'ワークフローメモ',
    'Transfer To' => '承認依頼先',
    'Select an author' => 'ユーザーを選択',
    'Return to previous step: [_1]' => '前の承認ステップに差し戻す: [_1]',
    'Remain in: [_1]' => '今の承認ステップのまま: [_1]',
    'Ready for next step: [_1]' => '次のステップに承認依頼を出す: [_1]',
    'Transfer...' => '承認依頼を出す...',

    # tmpl/audit_log.tmpl
    'Entry Audit Log' => '記事の承認履歴',
    'No audit log records could be found.' => '承認履歴はありません。',

    # tmpl/blog_config.tmpl
    'Email Notification' => 'メール通知',
    'Send email notifications for entry transfer and publish attempts.' => '承認依頼時にメール通知します。',
    'Automatic Editor Transfer' => '自動承認依頼',
    'Automatically transfer entries to first available editor upon publish attempt, where "first available" is defined as the editor with the most recent published entry.' => '記事を公開しようとしたときに、自動で承認者に記事を割り当てます。記事が割り当てられるのは、直近に記事公開をした承認者になります。',
);

1;
