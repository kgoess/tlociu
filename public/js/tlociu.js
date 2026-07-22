

document.addEventListener('DOMContentLoaded', () => {

    function toggleExpandableText(element) {
        element.classList.toggle('clamped');
    }

    function attachExpandableText() {
        const elements = document.querySelectorAll('.expandable-text');
        elements.forEach(element => {
            element.addEventListener('click', (event) => { toggleExpandableText(element) });
        });
    }

    function renderMarkdowns() {
        const markdownEls = document.querySelectorAll('.markdown');

        markdownEls.forEach(element => {
            const renderedHtml = marked.parse(element.innerHTML);
            element.innerHTML = renderedHtml;
        });
    }

    function initEntryListControls() {
        const list = document.querySelector('#entry-list');
        const sortButtons = Array.from(document.querySelectorAll('.sort-button'));
        if (!list || !sortButtons.length) return;

        const clearButton = document.querySelector('#clear-sort');
        const filterButtons = Array.from(document.querySelectorAll('.filter-button'));
        const panelToggle = document.querySelector('#list-controls-toggle');
        const panel = document.querySelector('#list-controls-panel');
        const summary = document.querySelector('#list-controls-summary');
        const originalOrder = Array.from(list.children);

        // Active sorts in priority order, e.g.
        // [{column: 'language', dir: 'asc'}, {column: 'year', dir: 'asc'}]
        let sortKeys = [];
        let filter = 'all';

        sortButtons.forEach(btn => { btn.dataset.label = btn.textContent.trim(); });

        try {
            const saved = JSON.parse(localStorage.getItem('tlociu.sortKeys') || '[]');
            if (Array.isArray(saved)) {
                sortKeys = saved.filter(k => k && buttonFor(k.column));
            }
            const savedFilter = localStorage.getItem('tlociu.filter');
            if (filterButtons.some(b => b.dataset.filter === savedFilter)) {
                filter = savedFilter;
            }
        } catch (e) { /* corrupted saved state; start fresh */ }

        function buttonFor(column) {
            return sortButtons.find(b => b.dataset.columnName === column);
        }

        function applySort() {
            let items;
            if (sortKeys.length) {
                items = Array.from(list.children);
                items.sort((a, b) => {
                    for (const key of sortKeys) {
                        const sortAs = buttonFor(key.column).dataset.sortAs;
                        const av = a.dataset[key.column] || '';
                        const bv = b.dataset[key.column] || '';
                        if (!av || !bv) {
                            if (av === bv) continue;
                            return av ? -1 : 1; // missing values sort last either direction
                        }
                        const cmp = (sortAs === 'number')
                            ? (+av) - (+bv)
                            : av.localeCompare(bv, undefined, { sensitivity: 'base' });
                        if (cmp) return key.dir === 'desc' ? -cmp : cmp;
                    }
                    return 0;
                });
            } else {
                items = originalOrder;
            }
            items.forEach(item => list.appendChild(item));
        }

        function applyFilter() {
            Array.from(list.children).forEach(item => {
                const watched = item.dataset.watched === '1';
                const show = filter === 'all' || (filter === 'watched') === watched;
                item.style.display = show ? '' : 'none';
            });
        }

        function updateControls() {
            sortButtons.forEach(btn => {
                const index = sortKeys.findIndex(k => k.column === btn.dataset.columnName);
                btn.classList.toggle('active', index >= 0);
                let html = btn.dataset.label;
                if (index >= 0) {
                    html += ' <span class="sort-dir">'
                        + (sortKeys[index].dir === 'desc' ? '↓' : '↑')
                        + '</span>';
                    if (sortKeys.length > 1) {
                        html += '<span class="sort-rank">' + (index + 1) + '</span>';
                    }
                }
                btn.innerHTML = html;
            });
            clearButton.hidden = !sortKeys.length;
            filterButtons.forEach(btn => {
                btn.classList.toggle('active', btn.dataset.filter === filter);
            });

            const parts = sortKeys.map(k =>
                buttonFor(k.column).dataset.label + ' ' + (k.dir === 'desc' ? '↓' : '↑'));
            if (filter !== 'all') {
                const filterBtn = filterButtons.find(b => b.dataset.filter === filter);
                if (filterBtn) parts.push(filterBtn.textContent.trim());
            }
            summary.textContent = parts.length ? parts.join(' · ') : 'Sort & filter';
            summary.classList.toggle('has-selection', parts.length > 0);
        }

        function refresh() {
            applySort();
            applyFilter();
            updateControls();
            localStorage.setItem('tlociu.sortKeys', JSON.stringify(sortKeys));
            localStorage.setItem('tlociu.filter', filter);
        }

        sortButtons.forEach(btn => {
            btn.addEventListener('click', () => {
                const column = btn.dataset.columnName;
                const firstDir = btn.dataset.firstDir || 'asc';
                const existing = sortKeys.find(k => k.column === column);
                if (!existing) {
                    sortKeys.push({ column: column, dir: firstDir });
                } else if (existing.dir === firstDir) {
                    existing.dir = (firstDir === 'asc') ? 'desc' : 'asc';
                } else {
                    sortKeys = sortKeys.filter(k => k.column !== column);
                }
                refresh();
            });
        });

        clearButton.addEventListener('click', () => {
            sortKeys = [];
            refresh();
        });

        panelToggle.addEventListener('click', () => {
            const open = panel.hidden;
            panel.hidden = !open;
            panelToggle.setAttribute('aria-expanded', open ? 'true' : 'false');
            panelToggle.classList.toggle('open', open);
        });

        filterButtons.forEach(btn => {
            btn.addEventListener('click', () => {
                filter = btn.dataset.filter;
                refresh();
            });
        });

        refresh();
    }


    attachExpandableText();
    initEntryListControls();
    renderMarkdowns();
});
