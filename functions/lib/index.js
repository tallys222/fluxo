"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.parseBill = void 0;
const https_1 = require("firebase-functions/v2/https");
const params_1 = require("firebase-functions/params");
const admin = require("firebase-admin");
const https = require("https");
admin.initializeApp();
const GEMINI_API_KEY = (0, params_1.defineSecret)("GEMINI_API_KEY");
function callGemini(apiKey, body) {
    return new Promise((resolve, reject) => {
        const model = "gemini-2.5-flash-lite";
        const path = `/v1beta/models/${model}:generateContent?key=${apiKey}`;
        const bodyBuffer = Buffer.from(body, "utf8");
        const req = https.request({
            hostname: "generativelanguage.googleapis.com",
            path,
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "Content-Length": bodyBuffer.length,
            },
        }, (res) => {
            const chunks = [];
            res.on("data", (c) => chunks.push(Buffer.from(c)));
            res.on("end", () => {
                const text = Buffer.concat(chunks).toString("utf8");
                if (res.statusCode && res.statusCode >= 400) {
                    reject(new Error(`Gemini ${res.statusCode}: ${text}`));
                }
                else {
                    resolve(text);
                }
            });
        });
        req.setTimeout(110000, () => {
            req.destroy();
            reject(new Error("Timeout na chamada ao Gemini"));
        });
        req.on("error", reject);
        req.write(bodyBuffer);
        req.end();
    });
}
exports.parseBill = (0, https_1.onCall)({
    region: "southamerica-east1",
    timeoutSeconds: 120,
    memory: "256MiB",
    maxInstances: 10,
    secrets: [GEMINI_API_KEY],
}, async (request) => {
    var _a, _b, _c, _d, _e, _f;
    console.log("=== parseBill START ===");
    if (!request.auth) {
        console.log("AUTH FAILED");
        throw new https_1.HttpsError("unauthenticated", "Login necessário.");
    }
    console.log("Auth OK, uid:", request.auth.uid);
    const { pdfBase64 } = request.data;
    console.log("pdfBase64 type:", typeof pdfBase64, "length:", (_a = pdfBase64 === null || pdfBase64 === void 0 ? void 0 : pdfBase64.length) !== null && _a !== void 0 ? _a : 0);
    if (!pdfBase64 || typeof pdfBase64 !== "string" || pdfBase64.length < 100) {
        throw new https_1.HttpsError("invalid-argument", "PDF inválido ou ausente.");
    }
    if (pdfBase64.length > 12000000) {
        throw new https_1.HttpsError("invalid-argument", "PDF muito grande. Máximo: 9MB.");
    }
    console.log("PDF size OK");
    let apiKey;
    try {
        apiKey = GEMINI_API_KEY.value();
        console.log("API key length:", (_b = apiKey === null || apiKey === void 0 ? void 0 : apiKey.length) !== null && _b !== void 0 ? _b : 0);
    }
    catch (e) {
        console.error("Error reading API key:", e);
        throw new https_1.HttpsError("internal", "Serviço não configurado.");
    }
    if (!apiKey) {
        console.error("API key is empty");
        throw new https_1.HttpsError("internal", "Serviço não configurado.");
    }
    const prompt = "Analise esta fatura de cartão de crédito brasileiro. " +
        "Retorne SOMENTE um JSON válido, sem markdown, sem explicações. " +
        "Formato exato:\n" +
        '{"issuer":"string","cardHolder":"string","dueDate":"DD/MM/YYYY","totalAmount":0.00,"transactions":[{"date":"DD/MM","description":"string","amount":0.00,"isCredit":false,"installmentInfo":null,"cardLast4":"string","categoryId":"string","categoryName":"string","categoryIcon":"string","categoryColor":"string"}]}\n\n' +
        "REGRAS:\n" +
        "- Inclua TODAS as compras de todos os cartões\n" +
        "- Exclua: pagamento anterior, anuidade zerada\n" +
        "- isCredit=true apenas para estornos/reembolsos\n" +
        "- installmentInfo: '02 DE 04' se parcelado, senão null\n" +
        "- amount sempre positivo\n" +
        "- description: nome limpo sem códigos\n\n" +
        "CATEGORIAS - escolha pelo nome do estabelecimento:\n" +
        "supermercado/Supermercado/🛒/#FF8C42 → SUPERMERCADO,MERCADO,ATACADO,EXTRA,CARREFOUR,ASSAI\n" +
        "restaurante/Restaurante/🍽️/#FF6348 → RESTAURANTE,IFOOD,RAPPI,LANCHONETE,PIZZARIA,BURGER,MCDONALDS\n" +
        "lanche/Lanche/☕/#C0763A → CAFE,PADARIA,SORVETE,ACAI,STARBUCKS\n" +
        "combustivel/Combustível/⛽/#636E72 → POSTO,SHELL,IPIRANGA,GASOLINA\n" +
        "uber_taxi/Uber/🚕/#FDCB6E → UBER,99APP,CABIFY,TAXI\n" +
        "farmacia/Farmácia/💉/#55EFC4 → FARMACIA,DROGARIA,DROGA,DROGASIL\n" +
        "saude/Saúde/💊/#00B894 → CLINICA,HOSPITAL,LABORATORIO,DENTISTA,UNIMED\n" +
        "academia/Academia/🏋️/#00B894 → ACADEMIA,SMARTFIT,BODYTECH,CROSSFIT\n" +
        "streaming/Streaming/📺/#6C5CE7 → NETFLIX,SPOTIFY,DISNEY,HBO,AMAZON PRIME,GLOBOPLAY\n" +
        "internet/Internet/📶/#00B8D9 → CLARO,VIVO,TIM,OI,NET\n" +
        "vestuario/Vestuário/👔/#FDCB6E → RENNER,RIACHUELO,MARISA,ZARA,C&A\n" +
        "eletronicos/Eletrônicos/📱/#74B9FF → AMERICANAS,MAGALU,CASAS BAHIA,KABUM\n" +
        "compras_online/Compras Online/🛍️/#A29BFE → AMAZON,MERCADO LIVRE,SHOPEE,SHEIN\n" +
        "lazer/Lazer/🎮/#FD79A8 → CINEMA,TEATRO,INGRESSO,STEAM\n" +
        "viagem/Viagem/✈️/#00CEC9 → HOTEL,AIRBNB,LATAM,GOL,AZUL,BOOKING\n" +
        "beleza/Beleza/💅/#FD79A8 → SALAO,BARBEARIA,OBOTICARIO,SEPHORA,NATURA\n" +
        "pets/Pets/🐾/#55EFC4 → PET,VETERINARIO,COBASI,PETZ\n" +
        "outros/Outros/💳/#9E9E9E → qualquer outro";
    let requestBody;
    try {
        requestBody = JSON.stringify({
            contents: [
                {
                    parts: [
                        { inline_data: { mime_type: "application/pdf", data: pdfBase64 } },
                        { text: prompt },
                    ],
                },
            ],
            generationConfig: { temperature: 0, maxOutputTokens: 8192 },
        });
        console.log("Request body built, size:", requestBody.length);
    }
    catch (e) {
        console.error("Error building request body:", e);
        throw new https_1.HttpsError("internal", "Erro ao preparar requisição.");
    }
    console.log("Calling Gemini...");
    let rawResponse;
    try {
        rawResponse = await callGemini(apiKey, requestBody);
        console.log("Gemini responded, raw length:", rawResponse.length);
    }
    catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        console.error("Gemini call failed:", msg);
        throw new https_1.HttpsError("internal", `Erro ao chamar IA: ${msg}`);
    }
    let geminiData;
    try {
        geminiData = JSON.parse(rawResponse);
    }
    catch (_g) {
        console.error("Failed to parse Gemini outer JSON:", rawResponse.substring(0, 200));
        throw new https_1.HttpsError("internal", "Resposta inválida do Gemini.");
    }
    const parts = (_f = (_e = (_d = (_c = geminiData.candidates) === null || _c === void 0 ? void 0 : _c[0]) === null || _d === void 0 ? void 0 : _d.content) === null || _e === void 0 ? void 0 : _e.parts) !== null && _f !== void 0 ? _f : [];
    const text = parts.filter((p) => p.text).map((p) => p.text).join("");
    if (!text) {
        console.error("No text in Gemini response:", JSON.stringify(geminiData).substring(0, 300));
        throw new https_1.HttpsError("internal", "Gemini não retornou texto.");
    }
    const clean = text.replace(/```json\s*/g, "").replace(/```\s*/g, "").trim();
    console.log("Gemini raw (first 500):", clean.substring(0, 500));
    let parsed;
    try {
        parsed = JSON.parse(clean);
    }
    catch (_h) {
        console.error("Failed to parse Gemini JSON:", clean.substring(0, 500));
        throw new https_1.HttpsError("internal", "Erro ao interpretar resposta da IA.");
    }
    console.log("=== parseBill SUCCESS ===");
    return { data: parsed };
});
//# sourceMappingURL=index.js.map