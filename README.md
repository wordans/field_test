# Field Test

:maple_leaf: A/B testing for Rails

- Designed for web and email
- Comes with a [nice dashboard](https://fieldtest.dokkuapp.com/)
- Seamlessly handles the transition from anonymous visitor to logged in user

Uses [Bayesian methods](http://www.evanmiller.org/bayesian-ab-testing.html) to evaluate results so you don’t need to choose a sample size ahead of time.

## Installation

Add this line to your application’s Gemfile:

```ruby
gem 'field_test'
```

Run:

```sh
rails g field_test:install
```

And mount the dashboard in your `config/routes.rb`:

```ruby
mount FieldTest::Engine, at: "field_test"
```

Be sure to [secure the dashboard](#security) in production.

![Screenshot](https://ankane.github.io/field_test/screenshot5.png)

## Getting Started

Add an experiment to `config/field_test.yml`.

```yml
experiments:
  button_color:
    variants:
      - red
      - green
      - blue
```

Refer to it in views, controllers, and mailers.

```ruby
button_color = field_test(:button_color)
```

When someone converts, record it with:

```ruby
field_test_converted(:button_color)
```

When an experiment is over, specify a winner:

```yml
experiments:
  button_color:
    winner: red
```

All calls to `field_test` will now return the winner, and metrics will stop being recorded.

## Features

You can specify a variant with query parameters to make testing easier

```
http://localhost:3000/?field_test[button_color]=red
```

Assign a specific variant to a user with:

```ruby
experiment = FieldTest::Experiment.find(:button_color)
experiment.variant(participant, variant: "red")
```

## Config

By default, bots are returned the first variant and excluded from metrics. Change this with:

```yml
exclude:
  bots: false
```

Keep track of when experiments started and ended. Use any format `Time.parse` accepts.

```yml
experiments:
  button_color:
    started_at: Dec 1, 2016 8 am PST
    ended_at: Dec 8, 2016 2 pm PST
```

Add a friendlier name and description with:

```yml
experiments:
  button_color:
    name: Buttons!
    description: >
      Different button colors
      for the landing page.
```

By default, variants are given the same probability of being selected. Change this with:

```yml
experiments:
  button_color:
    variants:
      - red
      - blue
    weights:
      - 90
      - 10
```

If the dashboard gets slow, you can speed it up with:

```yml
cache: true
```

## Funnels

For advanced funnels, we recommend an analytics platform like [Ahoy](https://github.com/ankane/ahoy) or [Mixpanel](https://mixpanel.com/).

You can use:

```ruby
field_test_experiments
```

to get all experiments and variants for a participant, and pass them as properties.

## Security

#### Devise

```ruby
authenticate :user, -> (user) { user.admin? } do
  mount FieldTest::Engine, at: "field_test"
end
```

#### Basic Authentication

Set the following variables in your environment or an initializer.

```ruby
ENV["FIELD_TEST_USERNAME"] = "moonrise"
ENV["FIELD_TEST_PASSWORD"] = "kingdom"
```

## Credits

A huge thanks to [Evan Miller](http://www.evanmiller.org/) for deriving the Bayesian formulas.

## History

View the [changelog](https://github.com/ankane/field_test/blob/master/CHANGELOG.md)

## Contributing

Everyone is encouraged to help improve this project. Here are a few ways you can help:

- [Report bugs](https://github.com/ankane/field_test/issues)
- Fix bugs and [submit pull requests](https://github.com/ankane/field_test/pulls)
- Write, clarify, or fix documentation
- Suggest or add new features
