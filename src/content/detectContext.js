export function detectContentType(text, selection, contextTypeSetter) {
    // Handle empty text
    const cleanText = text.trim();
    if (!cleanText) {
        contextTypeSetter("unknown");
        return;
    }

    // Check if selection is within a specific HTML element
    const parentElement = selection.rangeCount > 0 ?
        (selection.getRangeAt(0).commonAncestorContainer.nodeType === 3 ?
            selection.getRangeAt(0).commonAncestorContainer.parentElement :
            selection.getRangeAt(0).commonAncestorContainer) : null;

    // Create a confidence scoring system instead of binary detection
    let scores = {
        code: 0,
        math: 0,
        question: 0,
        term: 0,
        foreign: 0,
        paragraph: 0
    };

    // Add confidence based on HTML context
    if (parentElement) {
        if (parentElement.closest('pre > code, pre, .code-block, code')) {
            scores.code += 10; // Very high confidence if in code element
        }
        if (parentElement.closest('math, .math, .equation, .formula, .katex, .mathjax')) {
            scores.math += 10; // Very high confidence if in math element
        }
    }

    // Add confidence based on content patterns
    scores.code += scoreCodeConfidence(cleanText);
    scores.math += scoreMathConfidence(cleanText);
    scores.question += scoreQuestionConfidence(cleanText);
    scores.term += scoreTermConfidence(cleanText);
    scores.foreign += scoreForeignLanguage(cleanText);
    scores.paragraph += scoreParagraphConfidence(cleanText);

    // Contextual adjustments to reduce false positives
    if (scores.code > 0 && scores.math > 0) {
        // Math often contains symbols that can look like code
        if (cleanText.length < 20 && /[\d\+\-\*\/\=\<\>]/.test(cleanText)) {
            scores.code -= 2; // Reduce code confidence for short mathematical expressions
        }
    }

    if (scores.question > 0 && scores.code > 0) {
        // Questions about code are questions, not code
        if (cleanText.endsWith('?')) {
            scores.code -= 2;
        }
    }

    // Find the content type with highest confidence
    let maxScore = 0;
    let detectedType = "general"; // Default fallback

    for (const [type, score] of Object.entries(scores)) {
        if (score > maxScore) {
            maxScore = score;
            detectedType = type;
        }
    }

    // For very short text with low confidence, default to general
    if (maxScore < 2 && cleanText.length < 15) {
        detectedType = "general";
    }

    // Set the detected content type
    contextTypeSetter(detectedType);
}

/**
 * Calculate confidence score for code detection
 */
function scoreCodeConfidence(text) {
    let score = 0;
    
    // Common programming keywords
    const keywordMatches = text.match(/\b(const|let|var|function|class|if|else|for|while|return|import|export|this|async|await|try|catch)\b/g);
    if (keywordMatches) {
        score += Math.min(keywordMatches.length, 3); // Cap at 3 to prevent overconfidence
    }
    
    // Code operators and symbols
    if (/(=>|===?|!==?|&&|\|\||<<|>>|\+=|-=|\*=|\/=)/.test(text)) {
        score += 2;
    }
    
    // Brackets and block structure
    const brackets = text.match(/[{}[\]()]/g);
    if (brackets) {
        score += Math.min(brackets.length / 2, 2); // Cap at 2
    }
    
    // Code comments
    if (/\/\/.*$|\/\*[\s\S]*?\*\//.test(text)) {
        score += 1.5;
    }
    
    // Indentation patterns
    if (/^[ \t]+\w+/m.test(text)) {
        score += 0.5;
    }
    
    // Language-specific patterns
    if (/console\.log|document\.get|window\./.test(text)) {
        score += 1;
    }
    
    // Reduce confidence for very short text that might be misinterpreted
    if (text.length < 10) {
        score = Math.max(0, score - 1);
    }
    
    return score;
}

/**
 * Calculate confidence score for mathematical expression detection
 */
function scoreMathConfidence(text) {
    let score = 0;
    
    // Math symbols density
    const mathSymbolCount = (text.match(/[\+\-\*\/\^\=\<\>≤≥≠∑∏∫∂√π]/g) || []).length;
    score += Math.min(mathSymbolCount / 2, 2); // Cap at 2
    
    // Numbers and variables
    const numbersAndVars = (text.match(/\b\d+(\.\d+)?\b|[a-zA-Z]\s*[\+\-\*\/\^]/g) || []).length;
    score += Math.min(numbersAndVars / 2, 1.5);
    
    // Common math terms
    if (/\b(equation|function|integral|derivative|sum|product|limit|infinity)\b/i.test(text)) {
        score += 1;
    }
    
    // LaTeX-like notation
    if (/\\[a-zA-Z]+\{|\\frac\{|\\sum_/i.test(text)) {
        score += 2;
    }
    
    // Equations
    if (/=/.test(text) && /\d/.test(text) && !/['":]/.test(text)) {
        score += 1;
    }
    
    return score;
}

/**
 * Calculate confidence score for question detection
 */
function scoreQuestionConfidence(text) {
    let score = 0;
    
    // Explicit question mark at end
    if (text.trim().endsWith('?')) {
        score += 2;
    }
    
    // Question words at beginning
    if (/^(what|how|why|when|where|who|which|can|could|would|will|shall|should|may|might|do|does|did|is|are|was|were)\b/i.test(text.toLowerCase())) {
        score += 2;
    }
    
    // Command words that often indicate information requests
    if (/^(explain|describe|define|list|identify|analyze|compare|contrast|evaluate|examine|discuss|elaborate)/i.test(text.toLowerCase())) {
        score += 1.5;
    }
    
    // Question structure without question mark
    if (/\b(can you|could you|would you|will you|have you|do you)\b/i.test(text.toLowerCase()) && !text.includes('?')) {
        score += 1;
    }
    
    // Multiple question marks or interspersed questions
    const questionMarkCount = (text.match(/\?/g) || []).length;
    if (questionMarkCount > 1) {
        score += 0.5;
    }
    
    return score;
}

/**
 * Calculate confidence score for term/definition detection
 */
function scoreTermConfidence(text) {
    let score = 0;
    
    // Very short phrases are likely terms
    const wordCount = text.split(/\s+/).length;
    if (wordCount <= 3) {
        score += 2;
    } else if (wordCount <= 5) {
        score += 1;
    }
    
    // Absence of sentence-ending punctuation suggests a term
    if (!/[.!?]/.test(text)) {
        score += 1;
    }
    
    // Common patterns for terms
    if (/^[A-Z][a-z]+(\s+[A-Z][a-z]+)*$/.test(text)) { // Proper nouns or titles
        score += 1.5;
    }
    
    // Contains special technical/domain-specific markers
    if (/\b[A-Z]{2,}\b|\d+\.\d+\.\d+|^[A-Z][a-z]+[A-Z]/.test(text)) { // Acronyms, versions, camelCase
        score += 1;
    }
    
    // Not a complete sentence
    if (!/^\s*[A-Z].*[.!?]\s*$/.test(text)) {
        score += 0.5;
    }
    
    return score;
}

/**
 * Calculate confidence score for foreign language detection
 */
function scoreForeignLanguage(text) {
    let score = 0;
    
    // Non-ASCII character density
    const nonAsciiChars = (text.match(/[^\x00-\x7F]/g) || []).length;
    const nonAsciiRatio = nonAsciiChars / text.length;
    
    if (nonAsciiRatio > 0.3) {
        score += 3;
    } else if (nonAsciiRatio > 0.1) {
        score += 1.5;
    }
    
    // Common non-English language markers (diacritics and special characters)
    if (/[áàäâãåéèëêíìïîóòöôõúùüûçñßæøåœ]/i.test(text)) {
        score += 1;
    }
    
    // Right-to-left scripts
    if (/[\u0591-\u07FF\uFB1D-\uFDFD\uFE70-\uFEFC]/.test(text)) { // Hebrew, Arabic, etc.
        score += 2;
    }
    
    // CJK characters
    if (/[\u3040-\u30FF\u3400-\u4DBF\u4E00-\u9FFF\uF900-\uFAFF]/.test(text)) { // Japanese, Chinese, Korean
        score += 2;
    }
    
    // Not code (reduce confidence if looks like code)
    if (scoreCodeConfidence(text) > 2) {
        score -= 1;
    }
    
    return score;
}

/**
 * Calculate confidence score for paragraph detection
 */
function scoreParagraphConfidence(text) {
    let score = 0;
    
    // Length-based confidence
    const wordCount = text.split(/\s+/).length;
    if (wordCount > 30) {
        score += 3;
    } else if (wordCount > 15) {
        score += 2;
    } else if (wordCount > 8) {
        score += 1;
    }
    
    // Sentence structure
    const sentenceCount = text.split(/[.!?]+\s+/).length;
    if (sentenceCount > 2) {
        score += 2;
    } else if (sentenceCount > 1) {
        score += 1;
    }
    
    // Presence of connectors suggesting paragraph flow
    if (/\b(however|therefore|furthermore|moreover|consequently|additionally|nevertheless|although|despite|thus|hence|whereas)\b/i.test(text)) {
        score += 1;
    }
    
    // Formatted text often found in paragraphs
    if (/[""'']/g.test(text)) {
        score += 0.5;
    }
    
    return score;
}