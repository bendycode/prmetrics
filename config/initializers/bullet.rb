if Rails.env.development?
  Rails.application.configure do
    config.after_initialize do
      Bullet.enable = true
      Bullet.bullet_logger = true
      Bullet.console = true
      Bullet.rails_logger = true
      Bullet.add_footer = true
      Bullet.skip_html_injection = false

      # Detect N+1 queries
      Bullet.n_plus_one_query_enable = true

      # Detect eager loading that is not necessary
      Bullet.unused_eager_loading_enable = true

      # Detect missing counter cache
      Bullet.counter_cache_enable = true
    end
  end
end
