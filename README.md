Grape::Roar
------------

[![Gem Version](http://img.shields.io/gem/v/grape-roar.svg)](http://badge.fury.io/rb/grape-roar)
[![Build Status](http://img.shields.io/travis/ruby-grape/grape-roar.svg)](https://travis-ci.org/ruby-grape/grape-roar)
[![Dependency Status](https://gemnasium.com/ruby-grape/grape-roar.svg)](https://gemnasium.com/ruby-grape/grape-roar)
[![Code Climate](https://codeclimate.com/github/ruby-grape/grape-roar.svg)](https://codeclimate.com/github/ruby-grape/grape-roar)

Use [Roar](https://github.com/apotonick/roar) with [Grape](https://github.com/intridea/grape).

Demo
----

The [grape-with-roar](https://github.com/ruby-grape/grape-with-roar) project deployed [here on heroku](http://grape-with-roar.herokuapp.com).

Installation
------------

Add the `grape`, `roar` and `grape-roar` gems to Gemfile.

```ruby
gem 'grape'
gem 'roar'
gem 'grape-roar'
```

If you're upgrading from an older version of this gem, please see [UPGRADING](UPGRADING.md).

Usage
-----

### Tell your API to use Grape::Formatter::Roar

```ruby
class API < Grape::API
  format :json
  formatter :json, Grape::Formatter::Roar
end
```

### Use Grape's Present

Include Grape::Roar::Representer into a representer module *after* any Roar mixins, then use Grape's `present` keyword.

```ruby
module ProductRepresenter
  include Roar::JSON
  include Roar::Hypermedia
  include Grape::Roar::Representer

  property :title
  property :id
end
```

```ruby
get 'product/:id' do
  present Product.find(params[:id]), with: ProductRepresenter
end
```

Presenting collections works the same way. The following example returns an embedded set of products in the HAL Hypermedia format.

```ruby
module ProductsRepresenter
  include Roar::JSON::HAL
  include Roar::Hypermedia
  include Grape::Roar::Representer

  collection :entries, extend: ProductRepresenter, as: :products, embedded: true
end
```

```ruby
get 'products' do
  present Product.all, with: ProductsRepresenter
end
```

### Accessing the Request Inside a Representer

The formatter invokes `to_json` on presented objects and provides access to the requesting environment via the `env` option. The following example renders a full request URL in a representer.

```ruby
module ProductRepresenter
  include Roar::JSON
  include Roar::Hypermedia
  include Grape::Roar::Representer

  link :self do |opts|
    request = Grape::Request.new(opts[:env])
    "#{request.url}"
  end
end
```

### Decorators

If you prefer to use a decorator class instead of modules.

```ruby
class ProductRepresenter < Grape::Roar::Decorator
  include Roar::JSON
  include Roar::Hypermedia

  link :self do |opts|
    "#{request(opts).url}/#{represented.id}"
  end

  private

  def request(opts)
    Grape::Request.new(opts[:env])
  end
end
```

```ruby
get 'products' do
  present Product.all, with: ProductsRepresenter
end
```

### Relation Extensions

If you use either `ActiveRecord` or `Mongoid`, you can use the `Grape::Roar::Extensions::Relations` DSL to expose the relationships in between your models as a HAL response. The DSL methods used are the same regardless of what your ORM/ODM is, as long as there exists an adapter for it. 

#### Designing Representers

Arguments passed to `#relation` are forwarded to `roar`. Single member relations (e.g. `belongs_to`) are represented using `property`, collections are represented using `collection`, so as such, use only arguments that apply.

If `embedded` is `false`, a `_links` entry will be added. `#link_self` decorates the entity with a RESTful route to the current resource. A default base URI is constructed from a `Grape::Request` by concatenating the `#base_url` and `#script_name` properties. The resource path is extracted from the name of the relation.

Otherwise, the extensions attempt to look up the correct representer module/class for the objects (e.g. we infer the `extend` argument). You can always specify the correct representer to use on your own. 

##### Example Models

```ruby
  class Item < ActiveRecord::Base
    belongs_to :cart
  end

  class Cart < ActiveRecord::Base
    has_many :items  
  end
```

##### Example Representers

```ruby
class ItemEntity < Grape::Roar::Decorator
  include Roar::JSON
  include Roar::JSON::HAL
  include Roar::Hypermedia

  include Grape::Roar::Extensions::Relations

  relation :belongs_to, :cart, embedded: true

  link_self
end

class CartEntity < Grape::Roar::Decorator
  include Roar::JSON
  include Roar::JSON::HAL
  include Roar::Hypermedia

  include Grape::Roar::Extensions::Relations

  relation :has_many, :items, embedded: false

  link_self
end
```

Although this example uses `Grape::Roar::Decorator`, you can also use a module as show in prior examples above. If doing so, you no longer have to mix in `Grape::Roar::Representer`. 

##### Example Item
```javascript
{
    "_embedded": {
        "cart": {
            "_links": {
                "self": {
                    "href": "http://example.org/carts/1"
                },
                "items": [{
                    "href": "http://example.org/items/1"
                }]
            }
        }
    },
    "_links": {
        "self": {
            "href": "http://example.org/items/1"
        }
    }
}
```

##### Example Cart
```javascript
{
    "_links": {
        "self": {
            "href": "http://example.org/carts/1"
        },
        "items": [{
            "href": "http://example.org/items/1"
        }, {
            "href": "http://example.org/items/2"
        }, {
            "href": "http://example.org/items/3"
        }, {
            "href": "http://example.org/items/4"
        }, {
            "href": "http://example.org/items/5"
        }]
    }
}
```

#### Errors

Should you incorrectly describe a relationship (e.g. you specify has_one but your model specifies has_many), an exception will be raised to notify you of the mismatch:

```ruby
Grape::Roar::Extensions::Relations::Exceptions::InvalidRelationError:
  Expected Mongoid::Relations::Referenced::One, got Mongoid::Relations::Referenced::Many!
```

#### Change how URLs are presented

The `opts` hash below is the same one as shown in prior examples.

##### Override base URI mappings
```ruby
class BarEntity < Grape::Roar::Decorator
  include Roar::JSON
  include Roar::JSON::HAL
  include Roar::Hypermedia

  include Grape::Roar::Extensions::Relations

  # This is our default implementation
  map_base_url do |opts|
    request = Grape::Request.new(opts[:env])
    "#{request.base_url}#{request.script_name}"
  end

  relation :has_many, :bars, embedded: false
end
```

##### Override resource URI mappings
```ruby
class BarEntity < Grape::Roar::Decorator
  include Roar::JSON
  include Roar::JSON::HAL
  include Roar::Hypermedia

  include Grape::Roar::Extensions::Relations

  # This is our default implementation
  map_resource_path do |_opts, object, relation_name|
    "#{relation_name}/#{object.id}"
  end

  relation :has_many, :bars, embedded: false
end
```

Contributing
------------

See [CONTRIBUTING](CONTRIBUTING.md).

Copyright and License
---------------------

MIT License, see [LICENSE](LICENSE) for details.

(c) 2012-2014 [Daniel Doubrovkine](https://github.com/dblock) & Contributors, [Artsy](https://artsy.net)
