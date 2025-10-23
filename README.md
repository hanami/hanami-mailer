# Hanami::Mailer

Mail for Ruby applications.

## Version

**This branch contains the code for `hanami-mailer` 2.x.**

## Status

[![Gem Version](https://badge.fury.io/rb/hanami-mailer.svg)](https://badge.fury.io/rb/hanami-mailer)
[![CI](https://github.com/hanami/mailer/workflows/ci/badge.svg?branch=main)](https://github.com/hanami/mailer/actions?query=workflow%3Aci+branch%3Amain)

## Contact

* Home page: http://hanamirb.org
* Mailing List: http://hanamirb.org/mailing-list
* API Doc: http://rdoc.info/gems/hanami-mailer
* Bugs/Issues: https://github.com/hanami/mailer/issues
* Support: http://stackoverflow.com/questions/tagged/hanami
* Chat: http://chat.hanamirb.org

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'hanami-mailer'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install hanami-mailer

## Usage

### Conventions

  * Templates are searched under `Hanami::Mailer::Configuration#root`, set this value according to your app structure (eg. `"app/templates"`).
  * A mailer will look for a template with a file name that is composed by its full class name (eg. `"articles/index"`).
  * A template must have two concatenated extensions: one for the format and one for the engine (eg. `".html.erb"`).
  * The framework must be loaded before rendering the first time: `Hanami::Mailer.finalize(configuration)`.

### Mailers

A simple mailer looks like this:

```ruby
require 'hanami/mailer'
require 'ostruct'

# Create two files: `invoice.html.erb` and `invoice.txt.erb`

configuration = Hanami::Mailer::Configuration.new do |config|
  config.delivery_method = :test
end

class InvoiceMailer < Hanami::Mailer
  from "noreply@example.com"
  to ->(locals) { locals.fetch(:user).email }
end

configuration = Hanami::Mailer.finalize(configuration)

invoice = OpenStruct.new(number: 23)
mailer  = InvoiceMailer.new(configuration: configuration)
mail    = mailer.deliver(invoice: invoice)

mail
  # => #<Mail::Message:70303354246540, Multipart: true, Headers: <Date: Wed, 22 Mar 2017 11:48:57 +0100>, <From: noreply@example.com>, <To: user@example.com>, <Cc: >, <Bcc: >, <Message-ID: <58d25699e47f9_b4e13ff0c503e4f4632e6@escher.mail>>, <Subject: >, <Mime-Version: 1.0>, <Content-Type: multipart/alternative; boundary=--==_mimepart_58d25699e42d2_b4e13ff0c503e4f463186>, <Content-Transfer-Encoding: 7bit>>

mail.to_s
  # =>
  # From: noreply@example.com
  # To: user@example.com
  # Message-ID: <58d25699e47f9_b4e13ff0c503e4f4632e6@escher.mail>
  # Subject:
  # Mime-Version: 1.0
  # Content-Type: multipart/alternative;
  #  boundary="--==_mimepart_58d25699e42d2_b4e13ff0c503e4f463186";
  #  charset=UTF-8
  # Content-Transfer-Encoding: 7bit
  #
  #
  # ----==_mimepart_58d25699e42d2_b4e13ff0c503e4f463186
  # Content-Type: text/plain;
  #  charset=UTF-8
  # Content-Transfer-Encoding: 7bit
  #
  # Invoice #23
  #
  # ----==_mimepart_58d25699e42d2_b4e13ff0c503e4f463186
  # Content-Type: text/html;
  #  charset=UTF-8
  # Content-Transfer-Encoding: 7bit
  #
  # <html>
  #   <body>
  #     <h1>Invoice template</h1>
  #   </body>
  # </html>
  #
  # ----==_mimepart_58d25699e42d2_b4e13ff0c503e4f463186--
```

A mailer with `.to` and `.from` addresses and mailer delivery:

```ruby
require 'hanami/mailer'

configuration = Hanami::Mailer::Configuration.new do |config|
  config.delivery_method = :smtp,
                           address:              "smtp.gmail.com",
                           port:                 587,
                           domain:               "example.com",
                           user_name:            ENV['SMTP_USERNAME'],
                           password:             ENV['SMTP_PASSWORD'],
                           authentication:       "plain",
                           enable_starttls_auto: true
end

class WelcomeMailer < Hanami::Mailer
  return_path 'bounce@sender.com'
  from 'noreply@sender.com'
  to   'noreply@recipient.com'
  cc   'cc@sender.com'
  bcc  'alice@example.com'

  subject 'Welcome'
end

WelcomeMailer.new(configuration: configuration).call(locals)
```

### Locals

The set of objects passed in the `deliver` call are called `locals` and are available inside the mailer and the template.

```ruby
require 'hanami/mailer'
require 'ostruct'

user = OpenStruct.new(name: Luca', email: 'user@hanamirb.org')

class WelcomeMailer < Hanami::Mailer
  from    'noreply@sender.com'
  subject 'Welcome'
  to      ->(locals) { locals.fetch(:user).email }
end

WelcomeMailer.new(configuration: configuration).deliver(user: luca)
```

The corresponding `erb` file:

```erb
Hello <%= user.name %>!
```

### Scope

All public methods defined in the mailer are accessible from the template:

```ruby
require 'hanami/mailer'

class WelcomeMailer < Hanami::Mailer
  from    'noreply@sender.com'
  to      'noreply@recipient.com'
  subject 'Welcome'

  def greeting
    'Ahoy'
  end
end
```

```erb
<h2><%= greeting %></h2>
```

### Template

The template file must be located under the relevant `root` and must match the inflected snake case of the mailer class name.

```ruby
# Given this root
configuration.root      # => #<Pathname:app/templates>

# For InvoiceMailer, it looks for:
#  * app/templates/invoice_mailer.html.erb
#  * app/templates/invoice_mailer.txt.erb
```

If we want to specify a different template, we can do:

```ruby
class InvoiceMailer < Hanami::Mailer
  template 'invoice'
end

# It will look for:
#  * app/templates/invoice.html.erb
#  * app/templates/invoice.txt.erb
```

### Engines

The builtin rendering engine is [ERb](http://en.wikipedia.org/wiki/ERuby).

This is the list of the supported engines.
They are listed in order of **higher precedence**, for a given extension.
For instance, if [ERubis](http://www.kuwata-lab.com/erubis/) is loaded, it will be preferred over ERb to render `.erb` templates.

<table>
  <tr>
    <th>Engine</th>
    <th>Extensions</th>
  </tr>
  <tr>
    <td>Erubis</td>
    <td>erb, rhtml, erubis</td>
  </tr>
  <tr>
    <td>ERb</td>
    <td>erb, rhtml</td>
  </tr>
  <tr>
    <td>Redcarpet</td>
    <td>markdown, mkd, md</td>
  </tr>
  <tr>
    <td>RDiscount</td>
    <td>markdown, mkd, md</td>
  </tr>
  <tr>
    <td>Kramdown</td>
    <td>markdown, mkd, md</td>
  </tr>
  <tr>
    <td>Maruku</td>
    <td>markdown, mkd, md</td>
  </tr>
  <tr>
    <td>BlueCloth</td>
    <td>markdown, mkd, md</td>
  </tr>
  <tr>
    <td>Asciidoctor</td>
    <td>ad, adoc, asciidoc</td>
  </tr>
  <tr>
    <td>Builder</td>
    <td>builder</td>
  </tr>
  <tr>
    <td>CSV</td>
    <td>rcsv</td>
  </tr>
  <tr>
    <td>CoffeeScript</td>
    <td>coffee</td>
  </tr>
  <tr>
    <td>WikiCloth</td>
    <td>wiki, mediawiki, mw</td>
  </tr>
  <tr>
    <td>Creole</td>
    <td>wiki, creole</td>
  </tr>
  <tr>
    <td>Etanni</td>
    <td>etn, etanni</td>
  </tr>
  <tr>
    <td>Haml</td>
    <td>haml</td>
  </tr>
  <tr>
    <td>Less</td>
    <td>less</td>
  </tr>
  <tr>
    <td>Liquid</td>
    <td>liquid</td>
  </tr>
  <tr>
    <td>Markaby</td>
    <td>mab</td>
  </tr>
  <tr>
    <td>Nokogiri</td>
    <td>nokogiri</td>
  </tr>
  <tr>
    <td>Plain</td>
    <td>html</td>
  </tr>
  <tr>
    <td>RDoc</td>
    <td>rdoc</td>
  </tr>
  <tr>
    <td>Radius</td>
    <td>radius</td>
  </tr>
  <tr>
    <td>RedCloth</td>
    <td>textile</td>
  </tr>
  <tr>
    <td>Sass</td>
    <td>sass</td>
  </tr>
  <tr>
    <td>Scss</td>
    <td>scss</td>
  </tr>
  <tr>
    <td>Slim</td>
    <td>slim</td>
  </tr>
  <tr>
    <td>String</td>
    <td>str</td>
  </tr>
  <tr>
    <td>Yajl</td>
    <td>yajl</td>
  </tr>
</table>


### Configuration

__Hanami::Mailer__ can be configured with a DSL that determines its behavior.
It supports a few options:

```ruby
require "hanami/mailer"

configuration = Hanami::Mailer::Configuration.new do |config|
  # Set the root path where to search for templates
  # Argument: String, Pathname, #to_pathname, defaults to the current directory
  #
  config.root = "path/to/root"

  # Set the default charset for emails
  # Argument: String, defaults to "UTF-8"
  #
  config.default_charset = "iso-8859"

  # Set the delivery method
  # Argument: Symbol
  # Argument: Hash, optional configurations
  config.delivery_method = :smtp
end
```

### Attachments

Attachments can be added with the following API:

```ruby
class InvoiceMailer < Hanami::Mailer
  # ...
  before do |mail, locals|
    mail.attachments["invoice-#{locals.fetch(:invoice).number}.pdf"] = 'path/to/invoice.pdf'
  end
end
```

### Delivery Method

The global delivery method is defined through the __Hanami::Mailer__ configuration, as:

```ruby
configuration = Hanami::Mailer::Configuration.new do |config|
  config.delivery_method = :smtp
end
```

```ruby
configuration = Hanami::Mailer::Configuration.new do |config|
  config.delivery_method = :smtp, { address: "localhost", port: 1025 }
end
```

Builtin options are:

  * Exim (`:exim`)
  * Sendmail (`:sendmail`)
  * SMTP (`:smtp`, for local installations)
  * SMTP Connection (`:smtp_connection`, via `Net::SMTP` - for remote installations)
  * Test (`:test`, for testing purposes)

### Custom Delivery Method

Developers can specify their own custom delivery policy:

```ruby
require 'hanami/mailer'

class MandrillDeliveryMethod
  def initialize(options)
    @options = options
  end

  def deliver!(mail)
    # ...
  end
end

configuration = Hanami::Mailer::Configuration.new do |config|
  config.delivery_method = MandrillDeliveryMethod,
                           username: ENV['MANDRILL_USERNAME'],
                           password: ENV['MANDRILL_API_KEY']
end
```

The class passed to `.delivery_method=` must accept an optional set of options
with the constructor (`#initialize`) and respond to `#deliver!`.

### Multipart Delivery

All the email are sent as multipart messages by default.
For a given mailer, the framework looks up for associated text (`.txt`) and `HTML` (`.html`) templates and render them.

```ruby
InvoiceMailer.new(configuration: configuration).deliver({})           # delivers both text and html templates
InvoiceMailer.new(configuration: configuration).deliver(format: :txt) # delivers only text template
```

Please note that **they aren't both mandatory, but at least one of them MUST** be present.

## Versioning

__Hanami::Mailer__ uses [Semantic Versioning 2.0.0](http://semver.org)

## Copyright

Copyright © 2015-2021 Luca Guidi – Released under MIT License

This project was formerly known as Lotus (`lotus-mailer`).
