

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

    function attachSortButtons() {
        const elements = document.querySelectorAll('.sort-button');
        elements.forEach(element => {
            element.addEventListener('click', (event) => { sortEntryList(element.dataset.columnName, element.dataset.sortAs) });
        });
    }

    function sortEntryList(columnName, sortAs) {
        const list = document.querySelector('#entry-list');
        const items = Array.from(list.children); // Convert HTMLCollection to Array
        console.log('sorting entry-list by ', columnName);

        if (sortAs === 'number') {
            items.sort((a, b) => {
                return +a.dataset[columnName] - +b.dataset[columnName];
            });
        } else {
            items.sort((a, b) => {
                return a.dataset[columnName].localeCompare(b.dataset[columnName]);
            });
        }

        // Re-append sorted elements back to the parent element
        items.forEach(item => list.appendChild(item));
    }


    attachExpandableText();
    attachSortButtons();
    renderMarkdowns();
});
