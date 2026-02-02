/**
 * Visual Content Handler for Helpi
 * Handles images, charts, diagrams, and PDF content
 */

/**
 * Extract text from images using OCR (placeholder for future implementation)
 * Note: Actual OCR would require external API like Google Vision, Tesseract.js, etc.
 */
export async function extractTextFromImage(imageUrl) {
    // Placeholder - would integrate with OCR service
    return {
        success: false,
        message: 'OCR not yet implemented. Consider using Google Vision API or Tesseract.js',
        imageUrl
    };
}

/**
 * Analyze image content and generate description prompt
 */
export function generateImageAnalysisPrompt(visualContent) {
    const { type, src, alt, width, height } = visualContent;
    
    let prompt = 'I have selected an image on a webpage. ';
    
    if (alt) {
        prompt += `The image has alt text: "${alt}". `;
    }
    
    if (width && height) {
        prompt += `The image dimensions are ${width}x${height}px. `;
    }
    
    if (src) {
        prompt += `The image URL is: ${src}. `;
    }
    
    prompt += 'Please describe what this image likely contains based on the context and provide relevant information.';
    
    return prompt;
}

/**
 * Generate prompt for canvas/chart analysis
 */
export function generateChartAnalysisPrompt(visualContent) {
    const { type, width, height } = visualContent;
    
    return `I have selected a ${type} element (likely a chart or diagram) with dimensions ${width}x${height}px. 
This appears to be a dynamically rendered visualization. Please explain what type of chart or diagram this might be 
and what kind of information it typically displays.`;
}

/**
 * Generate prompt for SVG diagram analysis
 */
export function generateSVGAnalysisPrompt(visualContent) {
    const { outerHTML, width, height } = visualContent;
    
    // Extract text content from SVG
    const textContent = outerHTML.match(/<text[^>]*>(.*?)<\/text>/gi)?.map(t => 
        t.replace(/<[^>]*>/g, '').trim()
    ).filter(t => t).join(', ') || '';
    
    let prompt = `I have selected an SVG diagram with dimensions ${width}x${height}px. `;
    
    if (textContent) {
        prompt += `The diagram contains the following text elements: ${textContent}. `;
    }
    
    prompt += 'Please explain what this diagram likely represents and provide relevant information about its content.';
    
    return prompt;
}

/**
 * Check if current page is a PDF
 */
export function isPDFPage() {
    return document.contentType === 'application/pdf' || 
           window.location.pathname.toLowerCase().endsWith('.pdf') ||
           document.querySelector('embed[type="application/pdf"]') !== null;
}

/**
 * Extract text from PDF page (basic implementation)
 */
export function extractPDFText() {
    // Check if PDF.js is available
    if (typeof window.PDFViewerApplication !== 'undefined') {
        try {
            const pdfViewer = window.PDFViewerApplication;
            const currentPage = pdfViewer.page;
            const totalPages = pdfViewer.pagesCount;
            
            return {
                success: true,
                currentPage,
                totalPages,
                message: 'PDF detected. Text extraction requires PDF.js integration.'
            };
        } catch (error) {
            console.error('PDF extraction error:', error);
        }
    }
    
    // Fallback: try to get text from embed or iframe
    const pdfEmbed = document.querySelector('embed[type="application/pdf"], iframe[src*=".pdf"]');
    if (pdfEmbed) {
        return {
            success: false,
            message: 'PDF detected but text extraction not available. Please copy text manually.',
            element: pdfEmbed
        };
    }
    
    return {
        success: false,
        message: 'No PDF content detected'
    };
}

/**
 * Handle visual content selection
 */
export async function handleVisualSelection(visualContent, assistant) {
    const { type } = visualContent;
    
    let prompt;
    switch (type) {
        case 'image':
            prompt = generateImageAnalysisPrompt(visualContent);
            break;
        case 'canvas':
            prompt = generateChartAnalysisPrompt(visualContent);
            break;
        case 'svg':
            prompt = generateSVGAnalysisPrompt(visualContent);
            break;
        default:
            prompt = 'Please analyze the selected visual content.';
    }
    
    return prompt;
}

/**
 * Get visual content actions
 */
export function getVisualContentActions(visualContent) {
    const { type } = visualContent;
    
    const actions = [
        { class: 'describe-visual-btn', text: 'Describe' },
        { class: 'analyze-visual-btn', text: 'Analyze' }
    ];
    
    if (type === 'image') {
        actions.push({ class: 'extract-text-btn', text: 'Extract Text (OCR)' });
    }
    
    if (type === 'canvas' || type === 'svg') {
        actions.push({ class: 'explain-chart-btn', text: 'Explain Chart' });
    }
    
    return actions;
}
