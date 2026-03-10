# Okey101

Flutter + Go + PostgreSQL + Redis tabanlý, mobil ve masaüstü uyumlu online Okey / 101 platformu.

## Monorepo Yapýsý

- apps/client_flutter -> Oyuncu uygulamasý
- apps/admin_panel -> Admin paneli
- services/api_go -> API servisi
- services/realtime_go -> WebSocket / oyun sunucusu
- packages/game_rules -> Oyun kurallarý
- packages/shared_models -> Ortak veri modelleri
- infra/docker -> Docker altyapýsý
- docs -> Dokümantasyon

## Ýlk Hedef
- Kullanýcý sistemi
- Masa listesi
- Online masa
- Okey / 101 çekirdek oyun akýþý
- Admin temel paneli
