FROM ruby:3.2.2

COPY Gemfile* /tmp/

WORKDIR /tmp

RUN gem install bundler && \
    bundle install

ENV APP_PATH=/app
RUN mkdir $APP_PATH

WORKDIR $APP_PATH

COPY . .

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
