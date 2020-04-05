<?php
/**
 * Template part for displaying a restaurant Menu (CPT)
 *
 * @link https://developer.wordpress.org/themes/basics/template-hierarchy/
 *
 * @package ippuku_2019
*/

$tilde = '<span class="tilde">&#8764</span>';
?>

<?php $same = get_sub_field( 'same_prices' ); //error_log( '$same: ' . print_r( $same, true ) ); ?>

<section class="mb-3 mb-md-0">

  <header class="menu-section-header text-left text-md-center my-2 text-uppercase">

    <?php if( get_sub_field( 'section_title_ja' ) || get_sub_field( 'section_title_en' ) ):
      $connector = ( get_sub_field( 'section_title_ja' ) && get_sub_field( 'section_title_en' ) ) ? $tilde : ''; ?>

      <div class="h3 menu-section-title my-0">
        <span class="text-nowrap"><?php echo get_sub_field( 'section_title_ja' ); ?></span><?php echo $connector; ?><span class="text-nowrap"><?php echo get_sub_field( 'section_title_en' ); ?></span>
      </div><!-- .menu-subtitle -->

    <?php endif; ?>

  </header><!-- .menu-section-header -->

  <?php if( have_rows( 'items' ) ): ?>

    <?php if( $same ): ?>
      <div class="menu-section-group d-flex flex-column flex-md-row justify-content-md-between">
    <?php endif; ?>

    <div class="menu-items">

      <?php while( have_rows( 'items' ) ): the_row(); ?>

        <div class="menu-item-group d-flex flex-column flex-md-row justify-content-md-between">

          <div class="menu-description-group text-left">

            <div class="h3 menu-dish mt-1 mb-0 d-flex flex-row justify-content-between">
              <span class="mr-auto d-inline-block"><?php echo get_sub_field( 'dish_ja' ); ?></span>
            </div><!-- .menu-dish -->

            <div class="h6 menu-description text-green text-uppercase">
              <?php echo get_sub_field( 'description_en' ); ?>
            </div><!-- .menu-description -->

          </div><!-- .menu-description-group -->

          <?php if( $same != 1 ): ?>
            <div class="text-right text-nowrap">
              <div class="h3 text-red menu-price mt-0 mt-md-1">
                <?php echo ippuku_fancy_price( get_sub_field( 'price' ) ); ?>
              </div><!-- .menu-item-price -->
            </div><!-- .text-right -->
          <?php endif; ?>

        </div><!-- .menu-item-group -->

      <?php endwhile; ?>

    </div><!-- .menu-items -->

    <?php if( $same ): ?>
      <div class="h3 mt-0 text-red menu-price text-right text-nowrap d-md-flex flex-md-column justify-content-md-center">
        <?php echo ippuku_fancy_price( get_sub_field( 'same_price' ) ); ?>
      </div><!-- .menu-price -->
    </div><!-- .menu-section-group -->
    <?php endif; ?>

  <?php endif; ?>

</section><!-- .mb-3.mb-md-0 -->
