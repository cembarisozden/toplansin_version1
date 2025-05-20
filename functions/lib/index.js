"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.cancelSlotAndUpdateBookedSlots = exports.reserveSlotAndUpdateBookedSlots = exports.updateServerTime = exports.sendReservationStatusNotification = exports.notifyOwnerOnNewReservation = exports.logReservationChanges = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const admin = __importStar(require("firebase-admin"));
const https_1 = require("firebase-functions/v2/https");
const firestore_2 = require("firebase-admin/firestore");
admin.initializeApp();
var reservationLog_1 = require("./reservationLog");
Object.defineProperty(exports, "logReservationChanges", { enumerable: true, get: function () { return reservationLog_1.logReservationChanges; } });
/**
 * Get user's FCM token from users/{uid}.
 * @param {string} uid - user id
 * @return {Promise<string | undefined>} FCM token string or undefined
 */
async function getUserToken(uid) {
    var _a;
    const snap = await admin.firestore().collection("users").doc(uid).get();
    return (_a = snap.data()) === null || _a === void 0 ? void 0 : _a.fcmToken;
}
/**
 * Get owner's FCM token using hali_sahalar/{haliSahaId}.
 * @param {string} haliSahaId - field id
 * @return {Promise<string | undefined>} Owner token string or undefined
 */
async function getOwnerTokenByField(haliSahaId) {
    var _a;
    const snap = await admin
        .firestore()
        .collection("hali_sahalar")
        .doc(haliSahaId)
        .get();
    const ownerId = (_a = snap.data()) === null || _a === void 0 ? void 0 : _a.ownerId;
    if (!ownerId)
        return undefined;
    return getUserToken(ownerId);
}
/**
 * Centralized FCM push.
 * @param {string | undefined} token - fcm token
 * @param {string} title - title
 * @param {string} body - body
 * @param {string} reservationId - reservation id
 * @return {Promise<void>} void
 */
async function pushFCM(token, title, body, reservationId) {
    if (!token) {
        console.log("Bildirim gönderilmedi, hedef token yok.");
        return;
    }
    const message = {
        token,
        notification: {
            title,
            body,
        },
        data: {
            reservationId,
        },
    };
    try {
        const res = await admin.messaging().send(message);
        console.log("Bildirim başarıyla gönderildi:", res);
    }
    catch (err) {
        console.error("Bildirim gönderme hatası:", err);
    }
}
/**
 * 1️⃣  Fire when reservation is created.
 */
exports.notifyOwnerOnNewReservation = (0, firestore_1.onDocumentCreated)("reservations/{reservationId}", async (event) => {
    var _a;
    const reservation = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
    if (!reservation) {
        console.log("Yeni reservation verisi yok, çıkılıyor.");
        return;
    }
    if (reservation.status !== "Beklemede") {
        console.log("Status Beklemede değil, bildirim atlanıyor.");
        return;
    }
    const ownerToken = await getOwnerTokenByField(reservation.haliSahaId);
    await pushFCM(ownerToken, "Yeni Rezervasyon Talebi!", "Yeni bir rezervasyon talebi aldınız.", event.params.reservationId);
});
/**
 * 2️⃣  Fire when reservation is updated.
 */
exports.sendReservationStatusNotification = (0, firestore_1.onDocumentUpdated)("reservations/{reservationId}", async (event) => {
    var _a, _b, _c, _d, _e, _f, _g, _h;
    const beforeStatus = (_c = (_b = (_a = event.data) === null || _a === void 0 ? void 0 : _a.before) === null || _b === void 0 ? void 0 : _b.data()) === null || _c === void 0 ? void 0 : _c.status;
    const afterStatus = (_f = (_e = (_d = event.data) === null || _d === void 0 ? void 0 : _d.after) === null || _e === void 0 ? void 0 : _e.data()) === null || _f === void 0 ? void 0 : _f.status;
    if (beforeStatus === afterStatus) {
        console.log("Status değişmedi, bildirim gönderilmiyor.");
        return;
    }
    const reservation = (_h = (_g = event.data) === null || _g === void 0 ? void 0 : _g.after) === null || _h === void 0 ? void 0 : _h.data();
    if (!reservation) {
        console.log("Reservation verisi bulunamadı, çıkılıyor.");
        return;
    }
    const { userId, haliSahaId, lastUpdatedBy } = reservation;
    const userToken = await getUserToken(userId);
    const ownerToken = await getOwnerTokenByField(haliSahaId);
    let targetToken;
    let title = "";
    let body = "";
    if (afterStatus === "Onaylandı") {
        targetToken = userToken;
        title = "Rezervasyon Onaylandı!";
        body = "Rezervasyonunuz onaylandı.";
    }
    else if (afterStatus === "İptal Edildi" &&
        beforeStatus === "Beklemede") {
        if (!lastUpdatedBy)
            return;
        if (lastUpdatedBy === "user") {
            targetToken = ownerToken;
            title = "Kullanıcı Rezervasyonu İptal Etti";
            body = "Bekleyen rezervasyon kullanıcı tarafından iptal edildi.";
        }
        else if (lastUpdatedBy === "owner") {
            targetToken = userToken;
            title = "Rezervasyon İptal Edildi";
            body = "Saha sahibi rezervasyonunuzu iptal etti.";
        }
    }
    else if (afterStatus === "İptal Edildi" &&
        beforeStatus === "Onaylandı") {
        if (!lastUpdatedBy)
            return;
        if (lastUpdatedBy === "user") {
            targetToken = ownerToken;
            title = "Rezervasyon İptal Edildi";
            body = "Kullanıcı onaylanmış rezervasyonu iptal etti.";
        }
        else if (lastUpdatedBy === "owner") {
            targetToken = userToken;
            title = "Rezervasyon İptal Edildi";
            body = "Saha sahibi onaylanmış rezervasyonunuzu iptal etti.";
        }
    }
    else if (afterStatus === "Beklemede" &&
        beforeStatus !== "Beklemede") {
        targetToken = ownerToken;
        title = "Yeni Rezervasyon Talebi!";
        body = "Yeni bir rezervasyon talebi aldınız.";
    }
    await pushFCM(targetToken, title, body, event.params.reservationId);
});
/**
 * 3️⃣  Manually trigger server time update (via callable function)
 */
exports.updateServerTime = (0, https_1.onCall)(async (request) => {
    try {
        await admin.firestore().collection("server_time").doc("now").set({
            ts: firestore_2.FieldValue.serverTimestamp(),
        });
        console.log("server_time/now güncellendi.");
        return { success: true };
    }
    catch (error) {
        console.error("Zaman güncellenemedi:", error);
        return { success: false, error: error.message };
    }
});
// Dosyanın en altına bunu ekle
exports.reserveSlotAndUpdateBookedSlots = (0, https_1.onCall)(async (request) => {
    var _a;
    const data = request.data;
    const userId = (_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid;
    if (!userId) {
        throw new Error("Yetkisiz istek.");
    }
    const { haliSahaId, bookingString, } = data;
    if (!haliSahaId || !bookingString) {
        throw new Error("Eksik veri: haliSahaId, bookingString gerekiyor.");
    }
    const sahaRef = admin.firestore().collection("hali_sahalar").doc(haliSahaId);
    try {
        await admin.firestore().runTransaction(async (transaction) => {
            var _a;
            const sahaSnap = await transaction.get(sahaRef);
            if (!sahaSnap.exists) {
                throw new Error("Halı saha bulunamadı.");
            }
            const currentSlots = ((_a = sahaSnap.data()) === null || _a === void 0 ? void 0 : _a.bookedSlots) || [];
            if (currentSlots.includes(bookingString)) {
                throw new Error("Bu saat zaten rezerve edilmiş.");
            }
            transaction.update(sahaRef, {
                bookedSlots: admin.firestore.FieldValue.arrayUnion(bookingString),
            });
        });
        return { success: true };
    }
    catch (error) {
        console.error("Slot güncelleme hatası:", error.message);
        return { success: false, error: error.message };
    }
});
exports.cancelSlotAndUpdateBookedSlots = (0, https_1.onCall)(async (request) => {
    var _a;
    const data = request.data;
    const userId = (_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid;
    if (!userId) {
        throw new Error("Yetkisiz istek.");
    }
    const { haliSahaId, bookingString, } = data;
    if (!haliSahaId || !bookingString) {
        throw new Error("Eksik veri: haliSahaId, bookingString gerekiyor.");
    }
    const sahaRef = admin.firestore().collection("hali_sahalar").doc(haliSahaId);
    try {
        await admin.firestore().runTransaction(async (transaction) => {
            var _a;
            const sahaSnap = await transaction.get(sahaRef);
            if (!sahaSnap.exists) {
                throw new Error("Halı saha bulunamadı.");
            }
            const currentSlots = ((_a = sahaSnap.data()) === null || _a === void 0 ? void 0 : _a.bookedSlots) || [];
            // Eğer listede yoksa zaten bir şey yapma
            if (!currentSlots.includes(bookingString)) {
                console.log("Zaten kayıtlı değil");
                return;
            }
            transaction.update(sahaRef, {
                bookedSlots: admin.firestore.FieldValue.arrayRemove(bookingString),
            });
        });
        return { success: true };
    }
    catch (error) {
        console.error("Slot silme hatası:", error.message);
        return { success: false, error: error.message };
    }
});
//# sourceMappingURL=index.js.map