# Inception — przewodnik do zrozumienia projektu

## Najważniejszy model mentalny

Obraz Dockera jest niezmiennym szablonem zbudowanym przez Dockerfile. Kontener jest uruchomioną instancją obrazu. Dane, które mają przetrwać usunięcie kontenera, muszą znajdować się w wolumenie.

W tym projekcie ruch przebiega następująco:

```text
przeglądarka -> NGINX:443 -> WordPress/PHP-FPM:9000 -> MariaDB:3306
```

Tylko NGINX ma mapowanie portu na hosta. Pozostałe usługi komunikują się po prywatnej sieci Dockera, korzystając z nazw usług jako nazw DNS.

## Dlaczego trzy kontenery

Każdy kontener ma jedną odpowiedzialność i jeden główny proces:

- NGINX wykonuje `nginx -g 'daemon off;'`.
- WordPress wykonuje `php-fpm8.2 -F`.
- MariaDB wykonuje `mariadbd`.

Skrypt entrypoint przygotowuje środowisko, a następnie używa `exec`. Dzięki temu właściwa usługa zastępuje skrypt i staje się PID 1. Sygnały zatrzymania trafiają do niej bez pośrednika.

## Dlaczego nie używamy sztucznych poleceń podtrzymujących

Kontener działa tak długo, jak długo działa jego proces PID 1. Prawidłowym rozwiązaniem jest uruchomienie prawdziwej usługi na pierwszym planie. sztuczne polecenia podtrzymujące oraz nieskończone pętle jedynie ukrywają fakt, że właściwy proces zakończył się albo został uruchomiony niepoprawnie.

## Kolejność startu

MariaDB ma healthcheck. WordPress ma zależność `service_healthy`, więc zaczyna konfigurację dopiero po gotowości bazy. WordPress również ma healthcheck PHP-FPM. NGINX zaczyna po gotowości WordPressa.

Samo `depends_on` bez healthchecka oznaczałoby jedynie kolejność utworzenia kontenerów, a nie gotowość aplikacji.

## Sekrety

`.env` zawiera nazwy i ustawienia, które nie są hasłami. Pliki `secrets/*.txt` zawierają hasła i są ignorowane przez Git. Compose montuje je pod `/run/secrets/` tylko w wymaganych kontenerach.

WordPress nie zapisuje hasła bazy w trwałym `wp-config.php`. Zamiast tego plik PHP odczytuje `/run/secrets/db_password` przy uruchomieniu aplikacji.

## Wolumeny

`wordpress_data` jest montowany do `/var/www/html` w WordPressie oraz tylko do odczytu w NGINX-ie. Dzięki temu PHP-FPM i NGINX widzą te same pliki aplikacji.

`mariadb_data` jest montowany wyłącznie do `/var/lib/mysql` w kontenerze MariaDB.

`docker compose down` usuwa kontenery, ale nie dane. `make purge` usuwa również dane hosta.

## TLS

NGINX generuje lokalny certyfikat samopodpisany. Konfiguracja dopuszcza tylko TLS 1.2 i TLS 1.3. Ostrzeżenie przeglądarki nie oznacza braku szyfrowania — oznacza, że lokalny urząd certyfikacji nie podpisał certyfikatu.

## Co umieć wyjaśnić na ewaluacji

- różnicę między obrazem, kontenerem i wolumenem;
- dlaczego tylko NGINX publikuje port;
- dlaczego `expose` nie jest potrzebne do komunikacji w sieci Compose;
- jak Docker DNS rozwiązuje nazwy `mariadb` i `wordpress`;
- jak działa inicjalizacja pustej bazy;
- dlaczego inicjalizacja jest idempotentna;
- dlaczego używamy `exec`;
- gdzie znajdują się sekrety;
- co usuwa `down`, `down -v`, `fclean` i `purge`;
- dlaczego NGINX i WordPress współdzielą wolumen plików tylko do odczytu po stronie NGINX-a.
