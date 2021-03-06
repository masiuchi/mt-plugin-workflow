############################################################################
# Copyright © 2006-2010 Six Apart Ltd.
# This program is free software: you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation, or (at your option) any later version.
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
# version 2 for more details. You should have received a copy of the GNU
# General Public License version 2 along with this program. If not, see
# <http://www.gnu.org/licenses/>.

package Workflow::CMS;

use Data::Dumper;
use Workflow::StepAssociation;
use MT::Util qw( ts2epoch format_ts epoch2ts relative_date );

sub plugin {
    return MT->component ('Workflow');
}

sub edit_workflow {
    my $app = shift;

    $app->load_tmpl ('workflow_edit.tmpl', {});
}

sub edit_step {
    my $app = shift;
}

sub list_workflow_step {
    my $app = shift;
    my $blog_id = $app->blog->id;
    $app->listing ({
        type    => 'workflow_step',
        terms   => {
            blog_id => $blog_id,
        },
        args    => {
            sort        => 'order',
            direction   => 'ascend'
        },
    });
}

sub view_workflow_step {
    my $app = shift;
    my $q   = $app->param;

    my $tmpl = plugin()->load_tmpl ('edit_workflow_step.tmpl');
    my $class = $app->model ('workflow_step');
    my %param = ();

    # General setup stuff here
    # (this should really be a genericly available thing in MT,
    # but it can't find the template unless we're in the plugin)

    $param{object_type} = 'workflow_step';
    my $id = $q->param ('id');
    my $obj;
    if ($id) {
        $obj = $class->load ($id);
    }
    else {
        $obj = $class->new;
    }

    my $cols = $class->column_names;
    # Populate the param hash with the object's own values
    for my $col (@$cols) {
        $param{$col} =
          defined $q->param($col) ? $q->param($col) : $obj->$col();
    }

    if ( $class->can('class_label') ) {
        $param{object_label} = $class->class_label;
    }
    if ( $class->can('class_label_plural') ) {
        $param{object_label_plural} = $class->class_label_plural;
    }

    # Now for the custom bits

    if (my $next = $obj->next) {
        $param{next_step_id} = $next->id;
    }

    if (my $prev = $obj->previous) {
        $param{previous_step_id} = $prev->id;
    }

    # Get the list of roles
    require MT::Role;
    my @roles = MT::Role->load ({}, { sort => 'name', direction => 'ascend' });

    my %role_assoc_hash = ();
    my %author_assoc_hash = ();
    if ($id) {
        require Workflow::StepAssociation;
        my @assocs = Workflow::StepAssociation->load ({ blog_id => $app->blog->id, step_id => $id });
        %role_assoc_hash = map { $_->assoc_id => 1 } grep { $_->type eq Workflow::StepAssociation::ROLE } @assocs;
        %author_assoc_hash = map { $_->assoc_id => 1 } grep { $_->type eq Workflow::StepAssociation::AUTHOR } @assocs;
    }
    else {
        # No id, so we're creating it at the end
        # so grab the last step and add one to the order col
        my $last_step = Workflow::Step->load ({ blog_id => $app->blog->id }, { sort => 'order', direction => 'descend', limit => 1 });
        my $last_order = $last_step ? $last_step->order : 0;

        $param{order} = $last_order + 1;
    }

    $param{roles} = [ map { { role_name => $_-> name, role_id => $_->id, role_checked => $role_assoc_hash{$_->id} } } @roles ];

    require MT::Author;
    require MT::Permission;
    # should probably be a bit more specific about the permissions here
    my @authors = MT::Author->load ({ type => MT::Author::AUTHOR },
        {
            sort => 'name',
            direction => 'ascend',
            join    => MT::Permission->join_on ('author_id', {
                blog_id => $app->blog->id,
            }),
        }
    );

    $param{authors} = [ map { { author_name => $_->name, author_id => $_->id, author_checked => $author_assoc_hash{$_->id} } } @authors ];

    $app->build_page ($tmpl, \%param);
}


sub view_audit_log {
    my $app = shift;
    my $id = $app->param ('id');
    require MT::Entry;
    my $entry = MT::Entry->load ($id);

    my $plugin = MT::Plugin::Workflow->instance;

    my $tmpl = $plugin->load_tmpl ('audit_log.tmpl') or die $plugin->errstr;
    my $blog = $entry->blog;
    $app->listing ({
        type    => 'workflow_audit_log',
        template    => $tmpl,
        terms   => {
            object_id    => $id,
            object_datasource   => 'entry',
        },
        code    => sub {
            my ($obj, $row) = @_;
            require MT::Author;
            my $a = MT::Author->load ($obj->created_by);
            $row->{username} = $a->name;
            if ($obj->transferred_to) {
                my $ta = MT::Author->load ($obj->transferred_to);
                $row->{transferred_to_username} = $ta->name;
            }
            else {
                $row->{transferred_to_username} = '';
            }
            my @actions = ();

            if (!$obj->old_status) {
                push @actions, 'Created';
            }
            elsif ($obj->edited) {
                push @actions, 'Edited';
            }

            if ($obj->old_status != $obj->new_status) {
                if ($obj->new_status == MT::Entry::HOLD()) {
                    push @actions, 'Unpublished';
                }
                elsif ($obj->new_status == MT::Entry::RELEASE()) {
                    push @actions, 'Published';
                }
                elsif ($obj->new_status == MT::Entry::FUTURE()) {
                    push @actions, 'Scheduled';
                }
            }

            if ($obj->transferred_to) {
                push @actions, 'Transferred';
            }

            $row->{action_taken} = join (' and ', @actions);

            if ( my $ts = $obj->created_on ) {
                    $row->{created_on_formatted} =
                      format_ts( '%b %e, %Y',
                        epoch2ts( $blog, ts2epoch( undef, $ts ) ), $blog, $app->user ? $app->user->preferred_language : undef );
                $row->{created_on_relative} = relative_date( $ts, time );
                # $row->{log_detail} = $log->description;
            }

        },

    });
}

sub save_workflow_order {
    my $app = shift;
    my @param = grep { /^\d+_order/ } $app->{'query'}->param;
    my $class = $app->model('workflow_step');
    for my $key (@param) {
        $key =~ /^(\d+)_order/;
        my $id = $1;
        my $step = $class->load($id);
        $step->order($app->param($key));
        $step->save || die $step->errstr;
    }
    return list_workflow_step($app);
}

###
### Callbacks
###

sub edit_entry_param {
    my ($cb, $app, $param, $tmpl) = @_;

    return unless ($param->{object_type} eq 'entry');

    my $step;
    my $e;
    if (!$param->{id}) {
        require Workflow::Step;
        $step = Workflow::Step->first_step ($param->{blog_id});
    }
    else {
        require MT::Entry;
        $e = MT::Entry->load ($param->{id});
        $step = $e->workflow_step;
        my $prev_owner = plugin()->_get_previous_owner ($param->{id});
    }

    my $status_field = $tmpl->getElementById ('status');
    $status_field->setAttribute ('shown', '0');

    # grab the current owner and publish status
    my $owner = $e ? $e->author_id : $param->{author_id};
    my $published = $e ? $e->status == 2 || $e->status == 4 : 0;

    require MT::Author;
    require MT::Permission;
    my @authors = MT::Author->load ({ status => MT::Author::ACTIVE, type => MT::Author::AUTHOR },
        {
            join    => MT::Permission->join_on ('author_id', [{ blog_id => $param->{blog_id}, author_id => { not => $owner } } => -and => [{ permissions => { like => '%publish_post%' } }, $published ? () : (-or => { permissions => { like => '%create_post%' } }) ] ], { unique => 1 }),
        });

    my %names = map { $_->id => $_->nickname || $_->name } @authors;
    @authors = sort { $names{$a->id} cmp $names{$b->id} } @authors;

    $param->{transfer_author_loop} = [ map { { transfer_author_id => $_->id, transfer_author_name => $names{$_->id} } } @authors ];

    my $workflow_author_transfer_field = $tmpl->createElement ('app:setting', { id => 'workflow_author_transfer', label => 'Transfer To', shown => 0 });
    my $innerHTML = qq{
        <select name="workflow_author_transfer" id="workflow_author_transfer">
            <option value="">Select an author</option>
            <mt:loop name="transfer_author_loop">
                <option value="<mt:var name="transfer_author_id">"><mt:var name="transfer_author_name"></option>
            </mt:loop>
        </select>
    };
    $workflow_author_transfer_field->innerHTML ($innerHTML);
    $tmpl->insertAfter ($workflow_author_transfer_field, $status_field);

    # We can't find a step, kick out
    # workflow_step takes care of grabbing the first step if the entry isn't in a step yet
    # return if (!$step);

    if ($step) {
        $param->{workflow_has_step} = 1;
        $param->{workflow_has_previous_step} = $step->previous;
        if ($param->{workflow_has_previous_step}) {
            $param->{workflow_previous_step_name} = $step->previous->name;
        }

        $param->{workflow_current_step_name} = $step->name;

        if (!$step->next) {
            my $perms = $app->permissions;
            if ($perms->can_publish_post) {
                $param->{workflow_next_step_published} = 1;
            }
        }
        else {
            $param->{workflow_next_step_name} = $step->next->name;
        }
    }
    else {
        my $perms = $app->permissions;
        if ($perms->can_publish_post) {
            $param->{workflow_next_step_published} = 1;
        }
    }

    my $workflow_status_field = $tmpl->createElement ('app:setting', { id => 'workflow_status', label => 'Status' });
    $innerHTML = qq{
        <script type="text/javascript">
            function updateNote() {
                var sel = getByID('workflow_status');
                var val = sel.options[sel.selectedIndex].value;
                if (val < 0) {
                    TC.removeClassName (getByID('workflow_change_note-field'), 'hidden');
                }
                else {
                    TC.addClassName (getByID('workflow_change_note-field'), 'hidden');
                }

                if (val == -4) {
                    TC.removeClassName (getByID('workflow_author_transfer-field'), 'hidden');
                }
                else {
                    TC.addClassName (getByID('workflow_author_transfer-field'), 'hidden');
                }
            }
        </script>

    <select id="workflow_status" name="workflow_status" class="full-width" onchange="updateNote();">
        <mt:if name="workflow_has_previous_step"><option value="-3">Return to previous step: <mt:var name="workflow_previous_step_name"></option></mt:if>
        <mt:if name="workflow_has_step">
            <option value="-2" selected="selected">Remain in: <mt:var name="workflow_current_step_name"></option>
            <mt:else><option value="1"<mt:if name="status_draft"> selected="selected"</mt:if>>Unpublished</option></mt:else>
        </mt:if>
        <mt:if name="workflow_next_step_published">
            <option value="2"<mt:if name="status_publish"> selected="selected"</mt:if>>Published</option>
            <option value="4"<mt:if name="status_future"> selected="selected"</mt:if>>Scheduled</option>
            <mt:else>
            <option value="-1">Ready for next step: <mt:var name="workflow_next_step_name"></option>
        </mt:if>
        <option value="-4">Transfer...</option>
    </select>
    };
    $workflow_status_field->innerHTML ($innerHTML);
    $tmpl->insertBefore ($workflow_status_field, $workflow_author_transfer_field);

    my $workflow_change_field = $tmpl->createElement ('app:setting', { id => 'workflow_change_note', label => 'Change Note', shown => 0 });
    $innerHTML = qq{
        <textarea type="text" class="full-width short" rows="" cols="" id="workflow_change_note" name="workflow_change_note"></textarea>
    };
    $workflow_change_field->innerHTML ($innerHTML);
    $tmpl->insertAfter ($workflow_change_field, $workflow_status_field);

}

sub list_entry_source {
    my ($cb, $app, $tmpl) = @_;
    my $old = q{    </div>
</mt:setvarblock>
<mt:unless name="is_power_edit">};
    my $new = q{
        <mt:if name="workflow_transferred">
            <mtapp:statusmsg
                id="workflow_transferred"
                class="success">
                <__trans phrase="The [_1] has been transferred." params="<mt:var name="object_label">">
            </mtapp:statusmsg>
        </mt:if>
    };

    $$tmpl =~ s{\Q$old\E}{$new$old}ms;
}

sub list_entry_param {
    my ($cb, $app, $param, $tmpl) = @_;
    $param->{workflow_transferred} = $app->param ('workflow_transferred');
}

sub post_workflow_step_save {
    my ($cb, $app, $obj, $orig) = @_;

    my @role_ids = $app->param ('role_id');
    my @author_ids = $app->param ('author_id');

    my %role_id_hash = map { $_ => 1 } @role_ids;
    my %author_id_hash = map { $_ => 1 } @author_ids;

    require Workflow::StepAssociation;
    my @role_assocs = Workflow::StepAssociation->load ({ blog_id => $obj->blog_id, step_id => $obj->id, type => Workflow::StepAssociation::ROLE });
    foreach my $role_assoc (@role_assocs) {
        # If it's currently associated, and the hash doesn't have it
        # it's been removed, so remove the association
        # otherwise, remove it from the hash so we know we've covered it already
        if (!exists $role_id_hash{$role_assoc->assoc_id}) {
            $role_assoc->remove;
        }
        else {
            delete $role_id_hash{$role_assoc->assoc_id};
        }
    }

    # Now step through the remaining role ids and associate them
    require MT::Role;
    foreach my $id (keys %role_id_hash) {
        my $role = MT::Role->load ($id) or next;
        Workflow::StepAssociation->set_by_key ({ blog_id => $obj->blog_id, step_id => $obj->id, type => Workflow::StepAssociation::ROLE, assoc_id => $id });
    }

    my @author_assocs = Workflow::StepAssociation->load ({ blog_id => $obj->blog_id, step_id => $obj->id, type => Workflow::StepAssociation::AUTHOR });
    foreach my $author_assoc (@author_assocs) {
        if (!exists $author_id_hash{$author_assoc->assoc_id}) {
            $author_assoc->remove;
        }
        else {
            delete $author_id_hash{$author_assoc->assoc_id};
        }
    }

    require MT::Author;
    foreach my $id (keys %author_id_hash) {
        my $author = MT::Author->load ($id) or next;
        Workflow::StepAssociation->set_by_key ({ blog_id => $obj->blog_id, step_id => $obj->id, type => Workflow::StepAssociation::AUTHOR, assoc_id => $id });
    }

    1;
}

1;
