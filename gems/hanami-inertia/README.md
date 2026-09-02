# Hanami::Inertia 💎

First-class, lightweight **Inertia.js protocol adapter for Hanami 3.0**.

Build modern Single Page Applications (SPAs) with **Vue 3, React, or Svelte** using standard Hanami actions—without the need for complex API serializers or client-side routing.

---

## 📦 Installation

Add to your Gemfile:

```ruby
gem "hanami-inertia"
```

Then run:

```bash
bundle install
```

---

## 🚀 Quickstart with Hanami 3.0

### 1. Include in Base Action

```ruby
# app/action.rb
module MyApp
  class Action < Hanami::Action
    include Hanami::Inertia
  end
end
```

### 2. Render from Hanami Actions

```ruby
# app/actions/users/index.rb
module MyApp
  module Actions
    module Users
      class Index < MyApp::Action
        def handle(request, response)
          users = [{ id: 1, name: "Alice" }, { id: 2, name: "Bob" }]
          
          inertia request, response, "UsersIndex", {
            users: users,
            title: "Team Members"
          }
        end
      end
    end
  end
end
```

### 3. Setup Frontend (Vue 3 / React)

```typescript
// app/assets/js/app.ts
import { createApp, h } from 'vue';
import { createInertiaApp } from '@inertiajs/vue3';

createInertiaApp({
  resolve: (name) => import(`./pages/${name}.vue`),
  setup({ el, App, props, plugin }) {
    createApp({ render: () => h(App, props) })
      .use(plugin)
      .mount(el);
  },
});
```

---

## 🛡️ License

MIT License. Designed and crafted with ❤️ for the Hanami & Ruby community.
