import { createAppState } from './alpine-data.js';
import { materializeTemplateComponents } from './template-components.js';

function evaluateExpression(expression, state, scope = {}, extra = {}) {
  try {
    // eslint-disable-next-line no-new-func
    return new Function(
      '__state',
      '__scope',
      '__extra',
      `with(__state){with(__scope){with(__extra){ return (${expression}); }}}`
    )(state, scope, extra);
  } catch (err) {
    console.error('Expression eval error:', expression, err);
    return undefined;
  }
}

function executeStatement(statement, state, scope = {}, extra = {}) {
  try {
    // eslint-disable-next-line no-new-func
    return new Function(
      '__state',
      '__scope',
      '__extra',
      `with(__state){with(__scope){with(__extra){ ${statement}; }}}`
    )(state, scope, extra);
  } catch (err) {
    console.error('Statement exec error:', statement, err);
    return undefined;
  }
}

function assignExpression(targetExpression, value, state, scope = {}) {
  try {
    // eslint-disable-next-line no-new-func
    return new Function(
      '__state',
      '__scope',
      '__value',
      `with(__state){with(__scope){ ${targetExpression} = __value; }}`
    )(state, scope, value);
  } catch (err) {
    console.error('Assignment error:', targetExpression, err);
    return undefined;
  }
}

function isSimpleCallableExpression(expression) {
  return /^[A-Za-z_$][\w$]*(?:\.[A-Za-z_$][\w$]*)*$/.test(expression.trim());
}

function createReactiveState(rootObject, onChange) {
  const cache = new WeakMap();
  let rootProxy = null;

  const wrap = (target) => {
    if (!target || (typeof target !== 'object' && typeof target !== 'function')) {
      return target;
    }
    if (cache.has(target)) return cache.get(target);

    const proxy = new Proxy(target, {
      get(obj, prop, receiver) {
        const value = Reflect.get(obj, prop, receiver);
        if (typeof value === 'function') {
          return obj === rootObject ? value.bind(rootProxy) : value.bind(obj);
        }
        return wrap(value);
      },
      set(obj, prop, value, receiver) {
        const prev = Reflect.get(obj, prop, receiver);
        const ok = Reflect.set(obj, prop, value, receiver);
        if (!Object.is(prev, value)) {
          onChange();
        }
        return ok;
      },
      deleteProperty(obj, prop) {
        const hadProp = Reflect.has(obj, prop);
        const ok = Reflect.deleteProperty(obj, prop);
        if (hadProp) {
          onChange();
        }
        return ok;
      },
    });

    cache.set(target, proxy);
    return proxy;
  };

  rootProxy = wrap(rootObject);
  return rootProxy;
}

function parseForExpression(xForValue) {
  const match = xForValue.match(
    /^\s*(?:\(\s*([A-Za-z_$][\w$]*)\s*,\s*([A-Za-z_$][\w$]*)\s*\)|([A-Za-z_$][\w$]*))\s+in\s+(.+)$/
  );

  if (!match) {
    return null;
  }

  return {
    itemVar: match[1] || match[3],
    indexVar: match[2] || null,
    sourceExpr: match[4],
  };
}

function normalizeLoopSource(loopSource) {
  if (typeof loopSource === 'number') {
    const n = Number.isFinite(loopSource) ? Math.max(0, Math.floor(loopSource)) : 0;
    return Array.from({ length: n }, (_, i) => i + 1);
  }

  if (Array.isArray(loopSource)) return loopSource;
  if (loopSource && typeof loopSource[Symbol.iterator] === 'function') {
    return Array.from(loopSource);
  }

  if (loopSource && typeof loopSource === 'object') {
    return Object.values(loopSource);
  }

  return [];
}

function getClassAttr(el) {
  const classAttr = el.getAttribute('class');
  return classAttr == null ? '' : classAttr;
}

function setClassAttr(el, className) {
  const next = String(className || '').trim();
  if (!next) {
    el.removeAttribute('class');
    return;
  }
  el.setAttribute('class', next);
}

function parseFilterModelExpression(modelExpr) {
  const match = /^\s*filter\[['"]([^'"]+)['"]\]\[['"]([^'"]+)['"]\]\s*$/.exec(
    modelExpr || ''
  );
  if (!match) return null;
  return { group: match[1], key: match[2] };
}

function compileNode(node, state, rawState, scheduleUpdate, scope) {
  if (node.nodeType === Node.TEXT_NODE || node.nodeType === Node.COMMENT_NODE) {
    return {
      update() {},
      destroy() {},
    };
  }

  if (node.nodeType !== Node.ELEMENT_NODE) {
    return {
      update() {},
      destroy() {},
    };
  }

  const el = node;

  if (el.hasAttribute('x-for')) {
    const xFor = el.getAttribute('x-for');
    const parsed = parseForExpression(xFor || '');
    const marker = document.createComment('x-for');
    const parent = el.parentNode;
    parent.insertBefore(marker, el);

    const templateEl = el.tagName === 'TEMPLATE' ? el : el.cloneNode(true);
    templateEl.removeAttribute('x-for');
    el.remove();

    let rendered = [];

    const destroyRendered = () => {
      rendered.forEach((item) => {
        item.binding.destroy();
        item.nodes.forEach((n) => n.remove());
      });
      rendered = [];
    };

    return {
      update() {
        destroyRendered();

        if (!parsed) return;

        const source = evaluateExpression(parsed.sourceExpr, state, scope);
        const values = normalizeLoopSource(source);

        let insertAfter = marker;

        values.forEach((value, idx) => {
          const loopScope = Object.create(scope || null);
          loopScope[parsed.itemVar] = value;
          if (parsed.indexVar) loopScope[parsed.indexVar] = idx;

          const fragment =
            templateEl.tagName === 'TEMPLATE'
              ? templateEl.content.cloneNode(true)
              : templateEl.cloneNode(true);

          const nodesToInsert =
            fragment.nodeType === Node.DOCUMENT_FRAGMENT_NODE
              ? Array.from(fragment.childNodes)
              : [fragment];

          nodesToInsert.forEach((n) => {
            insertAfter.parentNode.insertBefore(n, insertAfter.nextSibling);
            insertAfter = n;
          });

          const compiledChildren = nodesToInsert.map((insertedNode) =>
            compileNode(insertedNode, state, rawState, scheduleUpdate, loopScope)
          );

          const binding = {
            update() {
              compiledChildren.forEach((b) => b.update());
            },
            destroy() {
              compiledChildren.forEach((b) => b.destroy());
            },
          };

          rendered.push({ binding, nodes: nodesToInsert });
        });

        rendered.forEach((item) => item.binding.update());
      },
      destroy() {
        destroyRendered();
        marker.remove();
      },
    };
  }

  if (el.hasAttribute('x-if')) {
    const xIfExpr = el.getAttribute('x-if') || 'false';
    const marker = document.createComment('x-if');
    const parent = el.parentNode;
    parent.insertBefore(marker, el);

    const templateEl = el.tagName === 'TEMPLATE' ? el : el.cloneNode(true);
    templateEl.removeAttribute('x-if');
    el.remove();

    let rendered = null;

    const destroyRendered = () => {
      if (!rendered) return;
      rendered.binding.destroy();
      rendered.nodes.forEach((n) => n.remove());
      rendered = null;
    };

    return {
      update() {
        const shouldShow = !!evaluateExpression(xIfExpr, state, scope);
        if (!shouldShow) {
          destroyRendered();
          return;
        }

        destroyRendered();

        const fragment =
          templateEl.tagName === 'TEMPLATE'
            ? templateEl.content.cloneNode(true)
            : templateEl.cloneNode(true);

        const nodesToInsert =
          fragment.nodeType === Node.DOCUMENT_FRAGMENT_NODE
            ? Array.from(fragment.childNodes)
            : [fragment];

        let insertAfter = marker;
        nodesToInsert.forEach((n) => {
          insertAfter.parentNode.insertBefore(n, insertAfter.nextSibling);
          insertAfter = n;
        });

        const compiledChildren = nodesToInsert.map((insertedNode) =>
          compileNode(insertedNode, state, rawState, scheduleUpdate, scope)
        );

        rendered = {
          nodes: nodesToInsert,
          binding: {
            update() {
              compiledChildren.forEach((b) => b.update());
            },
            destroy() {
              compiledChildren.forEach((b) => b.destroy());
            },
          },
        };

        rendered.binding.update();
      },
      destroy() {
        destroyRendered();
        marker.remove();
      },
    };
  }

  const directiveAttrs = Array.from(el.attributes).filter(
    (attr) => attr.name.startsWith(':') || attr.name.startsWith('@') || attr.name.startsWith('x-')
  );

  const cleanups = [];
  const updaters = [];

  if (el.hasAttribute('x-cloak')) {
    el.removeAttribute('x-cloak');
  }

  if (el.hasAttribute('x-ref')) {
    const refName = (el.getAttribute('x-ref') || '').trim();
    if (refName) {
      updaters.push(() => {
        rawState.$refs[refName] = el;
      });
    }
  }

  if (el.hasAttribute('x-text')) {
    const expr = el.getAttribute('x-text') || "''";
    updaters.push(() => {
      const value = evaluateExpression(expr, state, scope);
      el.textContent = value == null ? '' : String(value);
    });
  }

  if (el.hasAttribute('x-html')) {
    const expr = el.getAttribute('x-html') || "''";
    updaters.push(() => {
      const value = evaluateExpression(expr, state, scope);
      el.innerHTML = value == null ? '' : String(value);
    });
  }

  if (el.hasAttribute('x-show')) {
    const expr = el.getAttribute('x-show') || 'true';
    const originalDisplay = el.style.display;
    updaters.push(() => {
      const visible = !!evaluateExpression(expr, state, scope);
      el.style.display = visible ? originalDisplay : 'none';
    });
  }

  directiveAttrs
    .filter((attr) => attr.name.startsWith(':'))
    .forEach((attr) => {
      const bindName = attr.name.slice(1);
      const expr = attr.value;
      const staticClassName = getClassAttr(el);

      if (bindName === 'class') {
        updaters.push(() => {
          const bound = evaluateExpression(expr, state, scope);
          let dynamicClass = '';

          if (typeof bound === 'string') {
            dynamicClass = bound;
          } else if (Array.isArray(bound)) {
            dynamicClass = bound.filter(Boolean).join(' ');
          } else if (bound && typeof bound === 'object') {
            dynamicClass = Object.keys(bound)
              .filter((className) => !!bound[className])
              .join(' ');
          }

          setClassAttr(el, `${staticClassName} ${dynamicClass}`);
        });
        return;
      }

      if (bindName === 'disabled') {
        updaters.push(() => {
          const disabled = !!evaluateExpression(expr, state, scope);
          el.disabled = disabled;
          if (disabled) el.setAttribute('disabled', '');
          else el.removeAttribute('disabled');
        });
        return;
      }

      updaters.push(() => {
        const value = evaluateExpression(expr, state, scope);
        if (value === false || value == null) {
          el.removeAttribute(bindName);
        } else {
          el.setAttribute(bindName, String(value));
        }
      });
    });

  if (el.hasAttribute('x-model')) {
    const modelExpr = el.getAttribute('x-model') || '';
    const tagName = el.tagName.toLowerCase();
    const type = (el.getAttribute('type') || '').toLowerCase();
    const parsedFilterModel = parseFilterModelExpression(modelExpr);

    updaters.push(() => {
      const modelValue = evaluateExpression(modelExpr, state, scope);
      if (type === 'checkbox') {
        el.checked = !!modelValue;
      } else if (tagName === 'input' || tagName === 'textarea' || tagName === 'select') {
        el.value = modelValue == null ? '' : String(modelValue);
      }
    });

    const modelEventName = type === 'checkbox' || tagName === 'select' ? 'change' : 'input';
    const onModelInput = (evt) => {
      const nextValue = type === 'checkbox' ? evt.target.checked : evt.target.value;
      assignExpression(modelExpr, nextValue, state, scope);

      // Ensure filter checkboxes always trigger submit logic, even if @change binding
      // gets skipped or fails to execute in a transformed template.
      if (type === 'checkbox' && parsedFilterModel) {
        const handlerName = `handle_filter_change_${parsedFilterModel.group}`;
        const handler = state[handlerName];
        if (typeof handler === 'function') {
          handler.call(state, parsedFilterModel.key);
        } else if (typeof state.submit_query === 'function') {
          state.submit_query();
        }
      }
    };
    el.addEventListener(modelEventName, onModelInput);
    cleanups.push(() => el.removeEventListener(modelEventName, onModelInput));
  }

  directiveAttrs
    .filter((attr) => attr.name.startsWith('@'))
    .forEach((attr) => {
      const descriptor = attr.name.slice(1);
      const parts = descriptor.split('.');
      const eventName = parts[0];
      const modifiers = new Set(parts.slice(1));
      const expression = attr.value;
      const modelExpr = el.getAttribute('x-model') || '';
      const modelType = (el.getAttribute('type') || '').toLowerCase();
      const parsedFilterModel = parseFilterModelExpression(modelExpr);

      if (parsedFilterModel && modelType === 'checkbox' && eventName === 'change') {
        return;
      }

      const runHandler = (evt) => {
        if (modifiers.has('escape') && evt.key !== 'Escape') return;
        if (modifiers.has('prevent')) evt.preventDefault();

        if (isSimpleCallableExpression(expression)) {
          const callable = evaluateExpression(expression, state, scope, { $event: evt });
          if (typeof callable === 'function') {
            callable.call(state, evt);
            return;
          }
        }

        executeStatement(expression, state, scope, { $event: evt });
      };

      let handler = runHandler;

      if (modifiers.has('debounce')) {
        const delayToken = parts.find((p) => /ms$/.test(p));
        const delay = delayToken ? Number(delayToken.replace(/ms$/, '')) : 250;
        let timer = null;
        const wrapped = (evt) => {
          if (timer) clearTimeout(timer);
          timer = setTimeout(() => runHandler(evt), delay);
        };
        handler = wrapped;
        cleanups.push(() => {
          if (timer) clearTimeout(timer);
        });
      }

      if (modifiers.has('outside')) {
        const isVisible = () => {
          if (!el.isConnected) return false;
          if (el.hasAttribute('hidden')) return false;
          const computed = window.getComputedStyle(el);
          return computed.display !== 'none' && computed.visibility !== 'hidden';
        };

        const onOutside = (evt) => {
          if (!isVisible()) return;
          if (!el.contains(evt.target)) handler(evt);
        };
        document.addEventListener('click', onOutside);
        cleanups.push(() => document.removeEventListener('click', onOutside));
        return;
      }

      const target = modifiers.has('window') ? window : el;
      target.addEventListener(eventName, handler);
      cleanups.push(() => target.removeEventListener(eventName, handler));
    });

  const hasHtmlBinding = el.hasAttribute('x-html');
  const childBindings = hasHtmlBinding
    ? []
    : Array.from(el.childNodes).map((child) =>
        compileNode(child, state, rawState, scheduleUpdate, scope)
      );

  return {
    update() {
      updaters.forEach((fn) => fn());
      childBindings.forEach((binding) => binding.update());
    },
    destroy() {
      childBindings.forEach((binding) => binding.destroy());
      cleanups.forEach((cleanup) => cleanup());
    },
  };
}

export async function mountCohorterApp(rootEl) {
  const templateResp = await fetch('/app-template.html', { cache: 'no-store' });
  if (!templateResp.ok) {
    throw new Error(`Failed to load template: ${templateResp.status}`);
  }

  const templateHtml = await templateResp.text();
  rootEl.innerHTML = templateHtml;
  await materializeTemplateComponents(rootEl);

  const rawState = createAppState();
  rawState.$refs = {};
  rawState.$nextTick = (callback) => {
    if (typeof callback !== 'function') return;
    Promise.resolve().then(callback);
  };

  let disposed = false;
  let queued = false;

  let updateAll = () => {};
  const scheduleUpdate = () => {
    if (queued || disposed) return;
    queued = true;
    Promise.resolve().then(() => {
      queued = false;
      if (!disposed) updateAll();
    });
  };

  const state = createReactiveState(rawState, scheduleUpdate);
  const bindings = Array.from(rootEl.childNodes).map((child) =>
    compileNode(child, state, rawState, scheduleUpdate, Object.create(null))
  );

  updateAll = () => {
    rawState.$refs = {};
    bindings.forEach((binding) => binding.update());
  };

  updateAll();

  if (typeof state.submit_query === 'function') {
    state.submit_query();
  }

  return () => {
    disposed = true;
    bindings.forEach((binding) => binding.destroy());
    rootEl.innerHTML = '';
  };
}
