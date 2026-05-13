import { useState, useEffect, useCallback, useRef } from 'react';
import { ChevronDown, ChevronUp, PanelLeftClose } from 'lucide-react';

function copyGroup(state, group) {
  const src = state?.filter?.[group];
  if (!src) return {};
  const out = {};
  for (const k of Object.keys(src)) out[k] = src[k];
  return out;
}

function copyResult(state, group) {
  const src = state?.filter_result?.[group];
  if (!src) return {};
  const out = {};
  for (const k of Object.keys(src)) out[k] = src[k];
  return out;
}

function readSnapshot(state) {
  if (!state) return null;
  return {
    filter: {
      time:      copyGroup(state, 'time'),
      gender:    copyGroup(state, 'gender'),
      alive:     copyGroup(state, 'alive'),
      age:       copyGroup(state, 'age'),
      ethnicity: copyGroup(state, 'ethnicity'),
    },
    filterResult: {
      gender:    copyResult(state, 'gender'),
      alive:     copyResult(state, 'alive'),
      age:       copyResult(state, 'age'),
      ethnicity: copyResult(state, 'ethnicity'),
    },
    queryLen:          Array.isArray(state.query) ? state.query.length : 0,
    isTimeMenuOpen:     !!state.isTimeMenuOpen,
    isGenderMenuOpen:   !!state.isGenderMenuOpen,
    isAliveMenuOpen:    !!state.isAliveMenuOpen,
    isAgeMenuOpen:      !!state.isAgeMenuOpen,
    isEthnicityMenuOpen:!!state.isEthnicityMenuOpen,
  };
}


function FilterSection({ title, isOpen, onToggle, children }) {
  return (
    <li className="relative px-6 py-3">
      <button
        type="button"
        onClick={onToggle}
        className="inline-flex justify-between items-center w-full text-sm font-semibold transition-colors duration-150 hover:text-gray-800 dark:hover:text-white"
      >
        <span>{title}</span>
        {isOpen
          ? <ChevronUp  className="w-4 h-4" aria-hidden="true" />
          : <ChevronDown className="w-4 h-4" aria-hidden="true" />}
      </button>
      {isOpen && (
        <ul
          className="p-2 mt-2 overflow-hidden text-sm font-medium text-gray-600 dark:text-gray-500 rounded-md shadow-inner bg-gray-50 dark:bg-gray-900"
          aria-label="submenu"
        >
          {children}
        </ul>
      )}
    </li>
  );
}

function CheckItem({ checked, disabled, onChange, label, count }) {
  return (
    <li className="px-2 py-1 transition-colors duration-150 hover:text-gray-800 flex items-center">
      <input
        type="checkbox"
        checked={!!checked}
        disabled={!!disabled}
        onChange={onChange}
        className="disabled:opacity-25 mr-1 rounded text-purple-600 shadow-sm border-purple-400
                   focus:border-purple-800 focus:ring-0 focus:ring-offset-0
                   focus:ring-purple-600 focus:ring-opacity-50"
      />
      <span>{label}</span>
      {count !== undefined && (
        <span className="w-full text-right text-gray-400">
          {count !== '' ? `(${count})` : ''}
        </span>
      )}
    </li>
  );
}

export function FilterSidebar({ stateRef, subscribe, isOpen, onToggle }) {
  const [snap, setSnap] = useState(null);

  // Subscribe to Alpine.js state changes so React re-renders with fresh values.
  useEffect(() => {
    if (!subscribe) return;
    // Take an initial snapshot right away.
    setSnap(readSnapshot(stateRef.current));
    // Then update on every subsequent Alpine.js state flush.
    return subscribe(() => setSnap(readSnapshot(stateRef.current)));
  }, [subscribe, stateRef]);

  // Write a single filter key into Alpine.js state (goes through the reactive
  // proxy's set trap, which schedules a DOM update).
  const setFilter = useCallback((group, key, value) => {
    const s = stateRef.current;
    if (s?.filter?.[group] !== undefined) s.filter[group][key] = value;
  }, [stateRef]);

  // Call an Alpine.js method by name.
  const callMethod = useCallback((method, ...args) => {
    const s = stateRef.current;
    if (typeof s?.[method] === 'function') s[method](...args);
  }, [stateRef]);

  // Debounced handlers for the custom date / age range inputs.
  const timeDebounce = useRef(null);
  const ageDebounce  = useRef(null);

  const handleTimeCustom = useCallback((key, value) => {
    setFilter('time', key, value);
    clearTimeout(timeDebounce.current);
    timeDebounce.current = setTimeout(() => callMethod('handle_filter_change_time_custom'), 1000);
  }, [setFilter, callMethod]);

  const handleAgeCustom = useCallback((key, value) => {
    setFilter('age', key, value);
    clearTimeout(ageDebounce.current);
    ageDebounce.current = setTimeout(() => callMethod('handle_filter_change_age_custom'), 1000);
  }, [setFilter, callMethod]);

  if (!isOpen) return null;

  const f        = snap?.filter       ?? {};
  const r        = snap?.filterResult ?? {};
  const disabled = !snap || snap.queryLen === 0;

  // Helper: build a checkbox onChange that sets a value then calls a handler.
  const chkChange = (group, key, handler) => (e) => {
    setFilter(group, key, e.target.checked);
    callMethod(handler, key);
  };

  return (
    <aside className="z-20 w-72 overflow-y-auto bg-white dark:bg-gray-800 border-r border-gray-200 dark:border-gray-700 flex-shrink-0">
      <div className="py-4 text-gray-500 dark:text-gray-400">

        {/* Header row */}
        <div className="flex items-center justify-between mx-6">
          <span className="text-sm font-semibold text-gray-700 dark:text-gray-200">Filters</span>
          <button
            type="button"
            onClick={onToggle}
            className="p-1 rounded hover:bg-gray-100 dark:hover:bg-gray-800"
            title="Collapse filters"
            aria-label="Collapse filters"
          >
            <PanelLeftClose className="w-4 h-4" />
          </button>
        </div>

        <div className="flex justify-end mt-2 mr-6">
          <button
            type="button"
            onClick={() => callMethod('clear_all_filters_and_submit')}
            className="text-sm underline cursor-pointer"
          >
            clear all filters
          </button>
        </div>

        <ul className="mt-0">

          {/* ── First Mention Time ──────────────────────────────────── */}
          <FilterSection
            title="First Mention Time"
            isOpen={snap?.isTimeMenuOpen ?? true}
            onToggle={() => callMethod('toggleTimeMenu')}
          >
            <CheckItem checked={f.time?.['0']} disabled={disabled}
              onChange={chkChange('time', '0', 'handle_filter_change_time')} label="Any" />
            <CheckItem checked={f.time?.['1']} disabled={disabled}
              onChange={chkChange('time', '1', 'handle_filter_change_time')} label="Last 5 years" />
            <CheckItem checked={f.time?.['2']} disabled={disabled}
              onChange={chkChange('time', '2', 'handle_filter_change_time')} label="Last 10 years" />
            <CheckItem
              checked={f.time?.['3']}
              disabled={disabled || (f.time?.min === '' && f.time?.max === '')}
              onChange={chkChange('time', '3', 'handle_filter_change_time')}
              label="Custom"
            />
            {/* Custom date range */}
            <li className="px-2 py-1 flex items-start">
              <span className="invisible mr-1 w-4" />
              <div className="flex flex-col gap-1 mt-1">
                <div className="flex items-center gap-1">
                  <span className="w-6 text-xs">Min</span>
                  <input type="date" disabled={disabled}
                    value={f.time?.min ?? ''}
                    onChange={(e) => handleTimeCustom('min', e.target.value)}
                    className="h-5 p-0 text-gray-400 text-sm border-gray-300 rounded" />
                </div>
                <div className="flex items-center gap-1">
                  <span className="w-6 text-xs">Max</span>
                  <input type="date" disabled={disabled}
                    value={f.time?.max ?? ''}
                    onChange={(e) => handleTimeCustom('max', e.target.value)}
                    className="h-5 p-0 text-gray-400 text-sm border-gray-300 rounded" />
                </div>
              </div>
            </li>
          </FilterSection>

          {/* ── Gender ─────────────────────────────────────────────── */}
          <FilterSection
            title="Gender"
            isOpen={snap?.isGenderMenuOpen ?? true}
            onToggle={() => callMethod('toggleGenderMenu')}
          >
            {[['0','Any'],['1','Male'],['2','Female'],['3','Unknown']].map(([k, label]) => (
              <CheckItem key={k}
                checked={f.gender?.[k]} onChange={chkChange('gender', k, 'handle_filter_change_gender')}
                label={label} count={r.gender?.[k]} />
            ))}
          </FilterSection>

          {/* ── Alive / Died ────────────────────────────────────────── */}
          <FilterSection
            title="Alive / Died"
            isOpen={snap?.isAliveMenuOpen ?? true}
            onToggle={() => callMethod('toggleAliveMenu')}
          >
            {[['0','Any'],['1','Alive'],['2','Died']].map(([k, label]) => (
              <CheckItem key={k}
                checked={f.alive?.[k]} onChange={chkChange('alive', k, 'handle_filter_change_alive')}
                label={label} count={r.alive?.[k]} />
            ))}
          </FilterSection>

          {/* ── Age ─────────────────────────────────────────────────── */}
          <FilterSection
            title="Age"
            isOpen={snap?.isAgeMenuOpen ?? true}
            onToggle={() => callMethod('toggleAgeMenu')}
          >
            {[['0','Any'],['1','0 - 20'],['2','21 - 40'],['3','41 - 60'],['4','≥ 61']].map(([k, label]) => (
              <CheckItem key={k}
                checked={f.age?.[k]} onChange={chkChange('age', k, 'handle_filter_change_age')}
                label={label} count={r.age?.[k]} />
            ))}
            <CheckItem
              checked={f.age?.['5']}
              disabled={f.age?.min === '' && f.age?.max === ''}
              onChange={chkChange('age', '5', 'handle_filter_change_age')}
              label="Custom" count={r.age?.['5']}
            />
            {/* Custom age range */}
            <li className="px-2 py-1 flex items-start">
              <span className="invisible mr-1 w-4" />
              <div className="flex flex-col gap-1 mt-1">
                <div className="flex items-center gap-1">
                  <span className="w-6 text-xs">Min</span>
                  <input type="number" min="0" max="110"
                    value={f.age?.min ?? ''}
                    onChange={(e) => handleAgeCustom('min', e.target.value)}
                    className="h-5 p-0 w-20 text-gray-400 text-sm border-gray-300 rounded" />
                </div>
                <div className="flex items-center gap-1">
                  <span className="w-6 text-xs">Max</span>
                  <input type="number" min="0" max="110"
                    value={f.age?.max ?? ''}
                    onChange={(e) => handleAgeCustom('max', e.target.value)}
                    className="h-5 p-0 w-20 text-gray-400 text-sm border-gray-300 rounded" />
                </div>
              </div>
            </li>
          </FilterSection>

          {/* ── Ethnicity ───────────────────────────────────────────── */}
          <FilterSection
            title="Ethnicity"
            isOpen={snap?.isEthnicityMenuOpen ?? true}
            onToggle={() => callMethod('toggleEthnicityMenu')}
          >
            {[['0','Any'],['1','Asian'],['2','Black'],['3','White'],
              ['4','Mixed'],['5','Other'],['6','Unknown']].map(([k, label]) => (
              <CheckItem key={k}
                checked={f.ethnicity?.[k]} onChange={chkChange('ethnicity', k, 'handle_filter_change_ethnicity')}
                label={label} count={r.ethnicity?.[k]} />
            ))}
          </FilterSection>

        </ul>
      </div>
    </aside>
  );
}
