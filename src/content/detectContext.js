// contentDetection.js

export function detectContentType(text, selection, contextTypeSetter) {
    const cleanText = text.trim();
    if (!cleanText) {
        contextTypeSetter("unknown");
        return;
    }

    const parentElement = selection.rangeCount > 0 ?
        (selection.getRangeAt(0).commonAncestorContainer.nodeType === 3 ?
            selection.getRangeAt(0).commonAncestorContainer.parentElement :
            selection.getRangeAt(0).commonAncestorContainer) : null;

    // 1. Prioritize Code in Specific Elements
    if (parentElement?.closest('pre > code, pre, .code-block')) {
        contextTypeSetter("code");
        return;
    }
    if (isCodeText(cleanText)) {
        contextTypeSetter("code");
        return;
    }

    // 2. Prioritize Math in Specific Elements
    if (parentElement?.closest('math, .math, .equation, .formula, .katex, .mathjax') || isMathExpression(cleanText)) {
        contextTypeSetter("math");
        return;
    }

    // 3. Question Detection (more robust)
    if (isQuestion(cleanText)) {
        contextTypeSetter("question");
        return;
    }

    // 4. Term/Definition (shorter, less punctuation)
    if (isTermDefinition(cleanText)) {
        contextTypeSetter("term");
        return;
    }

    // 5. Foreign Language (longer, more non-English chars)
    if (isForeignLanguage(cleanText)) {
        contextTypeSetter("foreign");
        return;
    }

    // 6. Paragraph (longer text block)
    if (isParagraph(cleanText)) {
        contextTypeSetter("paragraph");
        return;
    }

    // Default fallback
    contextTypeSetter("general");
}

/**
 * Detect code from text patterns (concise version)
 */
function isCodeText(text) {
    const codeKeywords = /\b(const|let|var|function|class|if|else|for|while|return|import|export)\b/;
    const codeOperators = /(=>|::|===?|!==?|<<|>>|>>>|\/\/|\/\*)/;
    const codeBrackets = /[{}[\]()]/;
    return codeKeywords.test(text) && (codeOperators.test(text) || codeBrackets.test(text)) && text.split('\n').length <= 5;
}

/**
 * Detect math expressions (concise version)
 */
function isMathExpression(text) {
    const mathSymbols = /[\d\+\-\*\/\^\=\<\>∑∏∫∂√]|pi|e/;
    return mathSymbols.test(text.replace(/\s/g, '')) && text.length < 50;
}

/**
 * Detect questions of all types (concise version)
 */
function isQuestion(text) {
    return /^(what|how|why|when|where|who|can|could|would|will|shall|should|may|might|must|do|does|did|is|are|was|were)\b.*\?$/.test(text.toLowerCase()) ||
           /^(explain|describe|define|list|identify|analyze|evaluate|summarize)\b\s+\w+/.test(text.toLowerCase());
}

/**
 * Detect term/definition requests (concise version)
 */
function isTermDefinition(text) {
    return text.split(/\s+/).length <= 4 && !/[.!?]/.test(text);
}

/**
 * Detect foreign language text (concise version)
 */
function isForeignLanguage(text) {
    return text.length > 15 && /[^\x00-\x7F]/.test(text) && !isCodeText(text) && !isMathExpression(text);
}

/**
 * Detect paragraph content (concise version)
 */
function isParagraph(text) {
    return text.split(/\s+/).length > 10 && text.split(/[.!?]+/).length > 1;
}