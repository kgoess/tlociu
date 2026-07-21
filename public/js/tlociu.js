

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

    attachExpandableText();
    renderMarkdowns();
});
