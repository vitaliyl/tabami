import { createApp, h, type DefineComponent } from 'vue';
import { createInertiaApp } from '@inertiajs/vue3';
import Dashboard from './pages/Dashboard.vue';
import { isTauri } from './utils/api';
import '../css/app.css';

const appEl = document.getElementById('app');

if (isTauri()) {
  // Pure native Tauri desktop mode: mount Dashboard directly
  if (appEl) {
    createApp(Dashboard).mount(appEl);
  }
} else {
  // Web mode with Hanami backend: mount via Inertia
  if (appEl && !appEl.dataset.page) {
    appEl.dataset.page = JSON.stringify({
      component: 'Dashboard',
      props: {
        connections: [],
        active_connection: null,
        schemas: [],
        selected_schema: 'main',
        tables: [],
      },
      url: '/',
      version: '',
    });
  }

  createInertiaApp({
    resolve: (name) => {
      const pages = import.meta.glob<DefineComponent>('./pages/**/*.vue', { eager: true });
      const page = pages[`./pages/${name}.vue`];
      if (!page) {
        throw new Error(`Inertia page not found: ./pages/${name}.vue`);
      }
      return page.default || page;
    },
    setup({ el, App, props, plugin }) {
      createApp({ render: () => h(App, props) })
        .use(plugin)
        .mount(el);
    },
  });
}
