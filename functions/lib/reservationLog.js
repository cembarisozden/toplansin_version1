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
exports.logReservationChanges = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const admin = __importStar(require("firebase-admin"));
const db = admin.firestore();
exports.logReservationChanges = (0, firestore_1.onDocumentUpdated)("reservations/{reservationId}", async (event) => {
    var _a, _b, _c, _d, _e;
    const before = (_b = (_a = event.data) === null || _a === void 0 ? void 0 : _a.before) === null || _b === void 0 ? void 0 : _b.data();
    const after = (_d = (_c = event.data) === null || _c === void 0 ? void 0 : _c.after) === null || _d === void 0 ? void 0 : _d.data();
    if (!before || !after || before.status === after.status)
        return;
    const reservationId = event.params.reservationId;
    const logData = {
        reservationId,
        haliSahaId: after.haliSahaId,
        reservationDateTime: after.reservationDateTime,
        userId: after.userId,
        oldStatus: before.status,
        newStatus: after.status,
        by: (_e = after.lastUpdatedBy) !== null && _e !== void 0 ? _e : "unknown",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        expireAt: admin.firestore.Timestamp.fromMillis(Date.now() + 30 * 24 * 60 * 60 * 1000), // 30 gün sonrası
    };
    await db.collection("reservation_logs").add(logData);
});
//# sourceMappingURL=reservationLog.js.map