<?php
    global $ctx;
    if (! isset( $ctx ) ) {
        $mt = MT::get_instance();
        $ctx =& $mt->context();
    }
    global $customfield_types;
    $customfield_types[ 'contactform' ] = array(
        'column_def' => 'vchar',
    );
    $customfields = $ctx->stash( 'contactform_fields' );
    if (! isset( $customfields ) ) {
        require_once( 'class.mt_field.php' );
        $_field = new Field();
        $where = "field_type='contactform'";
        $customfields = $_field->Find( $where, FALSE, FALSE, array() );
    }
    if ( is_array( $customfields ) ) {
        require_once( 'block.mtcontactforms.php' );
        foreach ( $customfields as $field ) {
            $tag = $field->tag;
            $tag = strtolower( $tag );
            $ctx->unregister_function( "mt${tag}" );
            $ctx->add_tag( $tag, 'smarty_function_mt_contactforms_mtml_function' );
            $ctx->add_container_tag( "{$tag}loop", 'smarty_block_mt_contactforms_mtml_block' );
            $field_type = $field->field_type;
            $col_type = $customfield_types[ $field_type ][ 'column_def' ];
            if ( $col_type ) {
                BaseObject::install_meta( $field->field_obj_type, 'field.' . $field->field_basename, $col_type );
            }
        }
    }
    function smarty_function_mt_contactforms_mtml_function( $args, &$ctx ) {
        $this_tag = $ctx->this_tag();
        if (! $this_tag ) return;
        $this_tag = strtolower( $this_tag );
        $this_tag = preg_replace( '/^mt/i', '', $this_tag );
        $value = _hdlr_customfield_value( $args, $ctx, $this_tag );
        if (! $value ) {
            return '';
        }
        if ( $args[ 'raw' ] ) {
            return $value;
        }
        $mtml = __get_contactform_mtml_tmpl( $value, $ctx );
        require_once( 'modifier.mteval.php' );
        return smarty_modifier_mteval( $mtml, 1 );
    }
    function smarty_block_mt_contactforms_mtml_block( $args, $content, &$ctx, &$repeat ) {
        $this_tag = $ctx->this_tag();
        if (! $this_tag ) return;
        $this_tag = strtolower( $this_tag );
        $this_tag = preg_replace( '/^mt/i', '', $this_tag );
        $value = _hdlr_customfield_value( $args, $ctx, $this_tag );
        if (! $value ) {
            $repeat = FALSE;
            return '';
        }
        $args[ 'id' ] = $value;
        if ( $args[ 'raw' ] ) {
            return $value;
        }
        return smarty_block_mtcontactforms( $args, $content, $ctx, $repeat );
    }
    function __get_contactform_mtml_tmpl( $form_id, &$ctx ) {
        require_once( 'class.mt_contactformgroup.php' );
        $form = new ContactFormGroup;
        $form->Load( $form_id );
        if ( $form ) {
            $ctx->stash( 'contactformgroup', $form );
            if ( $template_id = $form->base_template_id ) {
                require_once( 'class.mt_template.php' );
                $template = new Template;
                $template->Load( $template_id );
                if ( $template ) {
                    $mtml = "<mt:contactforms id=\"${form_id}\">";
                    $mtml .= $template->text;
                    $mtml .= '</mt:contactforms>';
                    return $mtml;
                }

            }
        }
        return __get_contactform_tmpl( $form_id );
    }
?>