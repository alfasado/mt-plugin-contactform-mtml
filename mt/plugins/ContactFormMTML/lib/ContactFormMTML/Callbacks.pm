package ContactFormMTML::Callbacks;

use strict;
use warnings;

sub _param_edit_contactformgroup {
    my ( $cb, $app, $param, $tmpl ) = @_;
    my $component = MT->component( 'ContactFormMTML' );
    my $pointer_node = $tmpl->getElementById( 'not_save' );
    return unless $pointer_node;
    my $options_node = $tmpl->createElement( 'app:setting', {
        id => 'base_template_id',
        label => $component->translate( 'Base Template ID' ),
        show_label => 1,
    } );
    my $edit_link = '';
    if ( my $id = $param->{ id } ) {
        my $form = MT->model( 'contactformgroup' )->load( $id );
        if ( my $base_template_id = $form->base_template_id ) {
            my $template = MT->model( 'template' )->load( $base_template_id );
            if ( $template ) {
                my $edit_url = $app->base . $app->uri(
                    mode => 'view',
                    args => {
                        '_type' => 'template',
                        id      => $template->id,
                        blog_id => $template->blog_id
                    }
                );
                $edit_link = "&nbsp; <a href=\"${edit_url}\" target=\"blank\">";
                $edit_link .= $component->translate( 'Edit' );
                $edit_link .= '</a>';
            }
        }
    }
    my $inner = qq{
        <input type="text" name="base_template_id" id="base_template_id" class="text num" value="<mt:var name="base_template_id" escape="html">" />
        $edit_link
    };
    $options_node->innerHTML( $inner );
    $tmpl->insertAfter( $options_node, $pointer_node );
}

sub _init_tags {
    my $app = MT->instance();
    if ( ref( $app ) =~ /^MT::App/ ) {
        return 1 if $_[0]->name eq 'init_app';
    }
    return 1 if ( ref $app ) eq 'MT::App::Upgrader';
    my $cache = MT->request( 'plugin-contactform-mtml-init' );
    return 1 if $cache;
    MT->request( 'plugin-contactform-mtml-init', 1 );
    my $core = MT->component( 'commercial' );
    my $registry = $core->registry( 'tags', 'block' );
    my $registry_function = $core->registry( 'tags', 'function' );
    my $commercial = MT->component( 'commercial' );
    my $fields = $commercial->{ customfields };
    if (! $fields ) {
        if ( MT->request( 'powercms_no_contactform_field' ) ) {
            return;
        } else {
            $fields = MT->request( 'powercms_contactform_fields' );
            if (! $fields ) {
                my @contactform_fields = MT->model( 'field' )->load( { type => 'contactform' } );
                $fields = \@contactform_fields;
            }
        }
    }
    my $tags = $commercial->registry( 'tags' );
    for my $field ( @$fields ) {
        next if $field->type ne 'contactform';
        my $tag = $field->tag;
        $tag = lc( $tag );
        delete( $registry_function->{ $tag } );
        $registry_function->{ $tag } = sub { 
            my ( $ctx, $args, $cond ) = @_;
            my $app = MT->instance;
            my $blog = $ctx->stash( 'blog' );
            my $contactform;
            if ( ref( $app ) =~ /^MT::App/ ) {
                if ( my $mode = $app->mode ) {
                    if ( ( $mode eq 'confirm' ) || ( $mode eq 'submit' ) ) {
                        $contactform = 1;
                    }
                }
            }
            my $this_tag = lc ( $ctx->stash( 'tag' ) );
            my ( $start, $end );
            if (! $contactform ) {
                $start = '<mt:' . $this_tag . 'loop>';
                $end = '</mt:' . $this_tag . 'loop>';
            } else {
                $start = '<mt:Loop name="field_loop">';
                $end = '</mt:Loop>';
            }
            my $template;
            require CustomFields::Template::ContextHandlers;
            my $field = CustomFields::Template::ContextHandlers::find_field_by_tag( $ctx );
            local $ctx->{ __stash }{ field } = $field;
            my $value = CustomFields::Template::ContextHandlers::_hdlr_customfield_value( @_ );
            my $form = $ctx->stash( 'contactformgroup' );
            if (! $form ) {
                $form = MT->model( 'contactformgroup' )->load( $value );
            }
            if ( $form ) {
                if ( my $base_template_id = $form->base_template_id ) {
                    $template = MT->model( 'template' )->load( $base_template_id );
                }
            }
            if (! $template ) {
                require ContactForm::Plugin;
                $template = ContactForm::Plugin::_module_mtml();
            }
            if ( ref( $template ) eq 'MT::Template' ) {
                $template = $template->text;
            }
            require MT::Template::Tags::Filters;
            return MT::Template::Tags::Filters::_fltr_mteval( $start . $template . $end, 1, $ctx );
        };
    }
}

1;