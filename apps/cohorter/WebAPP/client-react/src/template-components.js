function replaceNodeWithHtml(node, html) {
  const template = document.createElement('template');
  template.innerHTML = html.trim();
  node.replaceWith(template.content);
}

async function materializeIncludes(rootEl) {
  let passes = 0;
  while (passes < 10) {
    const includeNodes = Array.from(rootEl.querySelectorAll('coh-include[src]'));
    if (includeNodes.length === 0) return;

    const sources = [...new Set(includeNodes.map((node) => node.getAttribute('src')).filter(Boolean))];
    const htmlBySource = new Map();

    await Promise.all(
      sources.map(async (src) => {
        const resp = await fetch(src, { cache: 'no-store' });
        if (!resp.ok) {
          throw new Error(`Failed to load component template ${src}: HTTP ${resp.status}`);
        }
        htmlBySource.set(src, await resp.text());
      })
    );

    includeNodes.forEach((node) => {
      const src = node.getAttribute('src');
      const html = htmlBySource.get(src) || '';
      replaceNodeWithHtml(node, html);
    });

    passes += 1;
  }

  console.warn('Exceeded include expansion pass limit. Check for recursive coh-include components.');
}

function renderInlineStatus() {
  return `
    <div class="flex items-center gap-3 text-gray-600 dark:text-gray-300 ml-6" aria-live="polite">
      <span x-text="running_status"></span>
      <span
        x-show="is_busy"
        x-cloak
        class="ml-2 inline-block h-6 w-6 border-2 border-purple-600 dark:border-purple-400 border-t-transparent rounded-full animate-spin"
        aria-hidden="true"></span>
      <span x-show="is_busy" x-cloak class="text-sm font-medium">Working…</span>
    </div>
  `;
}

function renderTopTermsTable({ showExpr, itemsExpr, capPercentage }) {
  const percentageExpr = capPercentage
    ? "Math.round(100*t['cnt']/query_result['all']) > 100 ? '100' : Math.round(100*t['cnt']/query_result['all']).toString()"
    : "Math.round(100*t['cnt']/query_result['all']).toString()";

  return `
    <div class="w-full mb-8 overflow-hidden rounded-lg shadow-xs" :class="${showExpr} ? '' : 'hidden'">
      <div class="w-full overflow-x-auto">
        <table class="border w-full whitespace-no-wrap transition-all">
          <thead>
            <tr class="text-xs font-semibold tracking-wide text-left text-gray-500 bg-white dark:bg-gray-900 uppercase border-b">
              <th class="px-4 py-3">Rank</th>
              <th class="px-4 py-3">Name</th>
              <th class="px-4 py-3">Count</th>
              <th class="px-4 py-3">Percentage</th>
            </tr>
          </thead>
          <tbody class="bg-white dark:bg-gray-900 dark:divide-gray-700 divide-gray-200 divide-y">
            <template x-for="(t,i) in ${itemsExpr}.slice((page-1)*10, page*10)">
              <tr class="text-gray-900 dark:text-white hover:bg-cool-gray-600 transition-all">
                <td class="w-14 px-4 py-3 text-sm" x-text="(page-1)*10+i+1"></td>
                <td class="w-full px-4 py-3 text-sm" x-text="t['str']"></td>
                <td class="w-14 px-4 py-3 text-sm" x-text="t['cnt'].toLocaleString()"></td>
                <td class="w-14 px-4 py-3 text-sm" x-text="${percentageExpr}"></td>
              </tr>
            </template>
          </tbody>
        </table>
        <div class="grid px-4 py-3 text-xs font-semibold tracking-wide text-gray-900 dark:text-white uppercase border-t bg-white dark:bg-gray-900 sm:grid-cols-9">
          <span class="flex items-center col-span-3 bg-white dark:bg-gray-900 text-gray-900 dark:text-white">
            Showing
            <span class="mx-1" x-text="${itemsExpr}.length == 0 ? '' : ((page - 1) * 10 + 1)"></span>
            -
            <span class="mx-1" x-text="${itemsExpr}.length == 0 ? '' : (page == Math.ceil(${itemsExpr}.length / 10) ? ${itemsExpr}.length : page * 10)"></span>
            of
            <span class="mx-2" x-text="${itemsExpr}.length"></span>
          </span>
          <span class="col-span-2"></span>
          <span class="flex col-span-4 mt-2 sm:mt-auto sm:justify-end">
            <nav aria-label="Table navigation">
              <ul class="inline-flex items-center">
                <li>
                  <button class="px-3 py-1 rounded-md rounded-l-lg focus:outline-none focus:shadow-outline-purple" aria-label="Previous" @click="if (page > 1) page--;">
                    <svg aria-hidden="true" class="w-4 h-4" :class="page <= 1 ? 'fill-gray-300' : 'fill-current'" viewBox="0 0 20 20">
                      <path d="M12.707 5.293a1 1 0 010 1.414L9.414 10l3.293 3.293a1 1 0 01-1.414 1.414l-4-4a1 1 0 010-1.414l4-4a1 1 0 011.414 0z" clip-rule="evenodd" fill-rule="evenodd"></path>
                    </svg>
                  </button>
                </li>
                <template x-for="page_i in (Math.ceil(${itemsExpr}.length / 10))">
                  <li>
                    <button
                      class="px-3 py-1 rounded-md focus:outline-none focus:shadow-outline-purple transition-colors duration-150"
                      :class="page == page_i ? 'text-gray-900 dark:text-white bg-purple-600 border border-r-0 border-purple-600 ' : ''"
                      x-text="page_i"
                      @click="page = page_i"></button>
                  </li>
                </template>
                <li>
                  <button class="px-3 py-1 rounded-md rounded-r-lg focus:outline-none focus:shadow-outline-purple" aria-label="Next" @click="if (page < Math.ceil(${itemsExpr}.length / 10)) page++;"><svg class="w-4 h-4" :class="page >= Math.ceil(${itemsExpr}.length / 10) ? 'fill-gray-300' : 'fill-current'" aria-hidden="true" viewBox="0 0 20 20"><path d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z" clip-rule="evenodd" fill-rule="evenodd"></path></svg></button>
                </li>
              </ul>
            </nav>
          </span>
        </div>
      </div>
    </div>
  `;
}

export async function materializeTemplateComponents(rootEl) {
  await materializeIncludes(rootEl);

  rootEl.querySelectorAll('coh-status-inline').forEach((node) => {
    replaceNodeWithHtml(node, renderInlineStatus());
  });

  rootEl.querySelectorAll('coh-top-terms-table').forEach((node) => {
    const showExpr = node.getAttribute('data-show');
    const itemsExpr = node.getAttribute('data-items');
    const capPercentage = node.getAttribute('data-cap') === 'true';

    if (!showExpr || !itemsExpr) {
      console.warn('coh-top-terms-table requires data-show and data-items attributes.');
      return;
    }

    replaceNodeWithHtml(node, renderTopTermsTable({ showExpr, itemsExpr, capPercentage }));
  });
}
