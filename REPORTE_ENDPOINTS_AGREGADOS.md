# 🚀 Especificación Técnica: Nuevos Endpoints Agregados (Master Academy API)

> **Documento Exclusivo de Endpoints Nuevos**  
> Este documento detalla **únicamente los endpoints que se agregaron** para sustituir los datos demo, simulaciones en memoria y guardados locales de la app móvil y web por persistencia real en la nube.  
> **Host Base:** `https://api.masteracademy.mx/api/v1` (o `http://localhost:8000/api/v1` en local)  
> **Headers Estándar:** `Content-Type: application/json`, `Accept: application/json`, `Authorization: Bearer <token>`

---

## 📋 Índice de Endpoints Nuevos

| # | Módulo | Método | Endpoint | ¿Para qué sirve? |
| :-: | :--- | :---: | :--- | :--- |
| **1** | [Seguridad & Cuenta](#1-seguridad-y-gestión-de-cuenta) | `POST` | `/auth/forgot-password` | Envío de correo para recuperación de contraseña olvidada. |
| **2** | [Seguridad & Cuenta](#1-seguridad-y-gestión-de-cuenta) | `DELETE` | `/auth/account` | Eliminación total de cuenta (requisito estricto Google/Apple). |
| **3** | [Lecciones & Material](#2-recursos-descargables-de-lección) | `GET` | `/lessons/{lessonId}/resources` | Descarga de PDFs, Excels y material de apoyo por clase. |
| **4** | [Reseñas & Estrellas](#3-calificaciones-y-reseñas-de-cursos) | `GET` | `/courses/{courseId}/reviews` | Lista opiniones reales y estrellas de otros estudiantes. |
| **5** | [Reseñas & Estrellas](#3-calificaciones-y-reseñas-de-cursos) | `POST` | `/courses/{courseId}/reviews` | Califica un curso (1 a 5) y recalcula el promedio general. |
| **6** | [Comentarios & Foros](#4-foros-y-comentarios-de-clase) | `GET` | `/courses/{courseId}/comments` | Preguntas de clase con respuestas anidadas del profesor/alumnos. |
| **7** | [Comentarios & Foros](#4-foros-y-comentarios-de-clase) | `POST` | `/courses/{courseId}/comments` | Publica una pregunta de clase o responde a otro estudiante. |
| **8** | [Comentarios & Foros](#4-foros-y-comentarios-de-clase) | `POST` | `/comments/{commentId}/like` | Da o quita "me gusta" a un comentario en tiempo real. |
| **9** | [Tutorías con Docente](#5-consultas-con-el-instructor-qa) | `GET` | `/me/inquiries` | Bandeja de consultas enviadas al profesor con sus respuestas. |
| **10**| [Tutorías con Docente](#5-consultas-con-el-instructor-qa) | `POST` | `/courses/{courseId}/inquiries` | Envía una duda técnica directa al profesor titular del curso. |
| **11**| [Notas del Estudiante](#6-cuaderno-de-notas-del-estudiante) | `GET` | `/me/notes` | Cuaderno de notas sincronizado en la nube (móvil y web). |
| **12**| [Notas del Estudiante](#6-cuaderno-de-notas-del-estudiante) | `POST` | `/lessons/{lessonId}/notes` | Crea o actualiza el apunte personal de una lección específica. |
| **13**| [Notas del Estudiante](#6-cuaderno-de-notas-del-estudiante) | `DELETE` | `/notes/{id}` | Elimina una nota personal del cuaderno. |
| **14**| [Cupones & Becas](#7-cupones-becas-y-descuentos) | `POST` | `/coupons/validate` | Valida código promocional en servidor (evita código duro en móvil). |
| **15**| [Cupones & Becas](#7-cupones-becas-y-descuentos) | `POST` | `/coupons/redeem` | Canjea beca del 100% y matricula automáticamente al usuario. |
| **16**| [Cupones & Becas](#7-cupones-becas-y-descuentos) | `GET` | `/me/coupons` | Lista cupones y becas canjeadas en el perfil del estudiante. |
| **17**| [Diplomas Oficiales](#8-certificados-y-diplomas-con-código-qr) | `GET` | `/certificates` | Lista diplomas oficiales obtenidos tras completar el 100% del curso. |
| **18**| [Diplomas Oficiales](#8-certificados-y-diplomas-con-código-qr) | `GET` | `/certificates/verify/{uuid}` | Validación pública del diploma al escanear el código QR del PDF. |
| **19**| [Notificaciones](#9-centro-de-notificaciones) | `GET` | `/notifications` | Notificaciones del usuario (bienvenida, nuevos cursos, becas). |
| **20**| [Notificaciones](#9-centro-de-notificaciones) | `PATCH` | `/notifications/{id}/read` | Marca una notificación específica como leída. |
| **21**| [Notificaciones](#9-centro-de-notificaciones) | `POST` | `/notifications/read-all` | Marca todas las notificaciones como leídas. |
| **22**| [Soporte Técnico](#10-centro-de-soporte-técnico-tickets) | `POST` | `/support/tickets` | Registro formal de tickets de ayuda técnica en la base de datos. |
| **23**| [Checkout & Pagos](#11-comercio-checkout-y-pagos) | `POST` | `/courses/{courseId}/checkout` | Genera la orden con descuento aplicado y total a pagar. |
| **24**| [Checkout & Pagos](#11-comercio-checkout-y-pagos) | `POST` | `/orders/{orderId}/payments` | Procesa la transacción con la pasarela y activa la matrícula. |

---

## 1. Seguridad y Gestión de Cuenta

### 1.1 `POST /auth/forgot-password`
* **¿Para qué es?:** Sustituye la alerta simulada en pantalla. Permite al usuario ingresar su correo para recibir un enlace de recuperación de contraseña con token criptográfico temporal.
* **Autenticación:** Pública.
* **Payload:**
```json
{
  "email": "estudiante@masteracademy.mx"
}
```
* **Respuesta Exitosa (200 OK):**
```json
{
  "message": "Se ha enviado un enlace de recuperación a tu correo electrónico."
}
```

---

### 1.2 `DELETE /auth/account`
* **¿Para qué es?:** Permite que el usuario elimine definitivamente su cuenta y datos personales desde la pantalla de Perfil. **Requisito mandatorio de Apple App Store (Pauta 5.1.1) y Google Play.**
* **Autenticación:** Protegido (`Bearer Token`).
* **Respuesta Exitosa (200 OK):**
```json
{
  "message": "Tu cuenta y datos personales han sido eliminados correctamente."
}
```

---

## 2. Recursos Descargables de Lección

### 2.1 `GET /lessons/{lessonId}/resources`
* **¿Para qué es?:** Sustituye los archivos de prueba inyectados localmente en la app. Devuelve los archivos descargables reales (PDFs, manuales técnicos, plantillas XLSX) asociados a la clase.
* **Autenticación:** Protegido (`Bearer Token`).
* **Tabla Backend sugerida:** `lesson_resources` (`id`, `lesson_id`, `title`, `file_url`, `file_type`, `file_size`).
* **Respuesta Exitosa (200 OK):**
```json
{
  "data": [
    {
      "id": 501,
      "title": "Manual de Seguridad Zero Trust 2026 (PDF)",
      "file_url": "https://masteracademy.mx/storage/resources/manual_2026.pdf",
      "file_type": "pdf",
      "file_size": "2.4 MB"
    }
  ]
}
```

---

## 3. Calificaciones y Reseñas de Cursos

### 3.1 `GET /courses/{courseId}/reviews`
* **¿Para qué es?:** Sustituye el guardado local del teléfono (`master_course_reviews_X`). Permite que las opiniones y estrellas publicadas por un alumno en su teléfono aparezcan en la web y en los dispositivos de otros estudiantes.
* **Autenticación:** Pública.
* **Respuesta Exitosa (200 OK):**
```json
{
  "data": [
    {
      "id": "rev_1",
      "userName": "Carlos Mendoza",
      "userAvatar": null,
      "rating": 5.0,
      "reviewText": "Excelente explicación sobre Zero Trust y normativas de ciberseguridad.",
      "tags": ["Contenido Claro", "Excelente Instructor"],
      "createdAt": "2026-03-01T15:30:00Z"
    }
  ]
}
```

---

### 3.2 `POST /courses/{courseId}/reviews`
* **¿Para qué es?:** Registra la calificación (1.0 a 5.0) y opinión del estudiante, recalculando automáticamente el promedio general (`rating` y `reviews_count`) del curso en la base de datos.
* **Autenticación:** Protegido (`Bearer Token`).
* **Tabla Backend sugerida:** `course_reviews` (`id`, `course_id`, `user_id`, `rating`, `review_text`, `tags`, `created_at`).
* **Payload:**
```json
{
  "rating": 5.0,
  "review_text": "Los laboratorios prácticos superaron mis expectativas.",
  "tags": ["Práctico", "Actualizado"]
}
```
* **Respuesta Exitosa (201 Created):**
```json
{
  "message": "Tu reseña ha sido publicada con éxito.",
  "review": {
    "id": "rev_2",
    "rating": 5.0,
    "reviewText": "Los laboratorios prácticos superaron mis expectativas."
  }
}
```

---

## 4. Foros y Comentarios de Clase

### 4.1 `GET /courses/{courseId}/comments`
* **¿Para qué es?:** Sustituye los comentarios guardados en memoria del teléfono (`master_course_comments_X`). Proporciona el foro colaborativo de dudas y respuestas con soporte para anidación.
* **Query Params:** `lesson_id` (opcional, para filtrar preguntas de la clase que se está reproduciendo).
* **Autenticación:** Protegido (`Bearer Token`).
* **Respuesta Exitosa (200 OK):**
```json
{
  "data": [
    {
      "id": "comm_101",
      "courseId": "1",
      "lessonId": 101,
      "userName": "María González",
      "userAvatar": null,
      "content": "¿Dónde puedo descargar la plantilla de auditoría?",
      "likesCount": 3,
      "isLikedByMe": false,
      "createdAt": "2026-03-02T10:00:00Z",
      "replies": [
        {
          "id": "comm_102",
          "userName": "Víctor Atala (Instructor)",
          "content": "Hola María, la encuentras en la pestaña Recursos y Notas.",
          "createdAt": "2026-03-02T10:15:00Z"
        }
      ]
    }
  ]
}
```

---

### 4.2 `POST /courses/{courseId}/comments`
* **¿Para qué es?:** Publica una nueva pregunta en la clase o responde al hilo de otro alumno/instructor.
* **Autenticación:** Protegido (`Bearer Token`).
* **Tabla Backend sugerida:** `course_comments` (`id`, `course_id`, `lesson_id`, `user_id`, `parent_id`, `content`, `likes_count`, `created_at`).
* **Payload:**
```json
{
  "lesson_id": 101,
  "parent_id": null,
  "content": "¿Este curso incluye certificado con validez oficial?"
}
```

---

### 4.3 `POST /comments/{commentId}/like`
* **¿Para qué es?:** Da o retira "Me Gusta" a una pregunta de la comunidad.
* **Autenticación:** Protegido (`Bearer Token`).
* **Respuesta Exitosa (200 OK):**
```json
{
  "likes_count": 4,
  "is_liked": true
}
```

---

## 5. Consultas con el Instructor (Q&A)

### 5.1 `GET /me/inquiries`
* **¿Para qué es?:** Sustituye el historial local `master_instructor_inquiries_all`. Muestra al alumno sus preguntas enviadas a los profesores y el estado de la respuesta (`'Pendiente'` / `'Respondida'`).
* **Autenticación:** Protegido (`Bearer Token`).

---

### 5.2 `POST /courses/{courseId}/inquiries`
* **¿Para qué es?:** Envía una consulta técnica privada al profesor del curso desde el reproductor de video.
* **Autenticación:** Protegido (`Bearer Token`).
* **Tabla Backend sugerida:** `instructor_inquiries` (`id`, `user_id`, `course_id`, `lesson_title`, `subject`, `message`, `status`, `reply`, `replied_at`).
* **Payload:**
```json
{
  "lesson_title": "1.1 Introducción a Zero Trust",
  "subject": "Duda con la implementación en Docker",
  "message": "Profesor, al configurar el proxy inverso obtuve un error de cabeceras CORS..."
}
```

---

## 6. Cuaderno de Notas del Estudiante

### 6.1 `GET /me/notes`
* **¿Para qué es?:** Sustituye las notas guardadas en el almacenamiento privado del celular (`master_student_notes_all`). Permite que los apuntes tomados en el móvil se sincronicen en la web.
* **Autenticación:** Protegido (`Bearer Token`).
* **Respuesta Exitosa (200 OK):**
```json
{
  "data": [
    {
      "id": "note_101",
      "courseId": "1",
      "courseTitle": "Desarrollo Web Fullstack & Ciberseguridad",
      "lessonId": 101,
      "lessonTitle": "1.1 Introducción a Zero Trust",
      "content": "Recordar auditar las claves criptográficas cada 90 días.",
      "updatedAt": "2026-03-02T16:00:00Z"
    }
  ]
}
```

---

### 6.2 `POST /lessons/{lessonId}/notes`
* **¿Para qué es?:** Guarda o actualiza el apunte del estudiante mientras ve la clase.
* **Autenticación:** Protegido (`Bearer Token`).
* **Tabla Backend sugerida:** `student_notes` (`id`, `user_id`, `course_id`, `lesson_id`, `content`, `updated_at`).
* **Payload:**
```json
{
  "course_id": 1,
  "content": "Conceptos de Zero Trust: verificación explícita y mínimo privilegio."
}
```

---

### 6.3 `DELETE /notes/{id}`
* **¿Para qué es?:** Elimina una nota personal del cuaderno del alumno.
* **Autenticación:** Protegido (`Bearer Token`).

---

## 7. Cupones, Becas y Descuentos

### 7.1 `POST /coupons/validate`
* **¿Para qué es?:** Sustituye la validación con código duro en la app (`if code == 'MASTER100'`). Consulta la base de datos para saber si el cupón está activo, si ha expirado y qué porcentaje descuenta.
* **Autenticación:** Protegido (`Bearer Token`).
* **Tabla Backend sugerida:** `coupons` (`id`, `code`, `discount_percentage`, `discount_amount`, `course_id`, `max_uses`, `used_count`, `expires_at`, `is_active`).
* **Payload:**
```json
{
  "code": "MASTER100",
  "course_id": 1
}
```
* **Respuesta Exitosa (200 OK):**
```json
{
  "valid": true,
  "code": "MASTER100",
  "discount_percentage": 100,
  "discount_amount": 399.00,
  "description": "Beca de Acceso Completo 100%"
}
```

---

### 7.2 `POST /coupons/redeem`
* **¿Para qué es?:** Si el cupón cubre el 100% de beca, canjea el código, descuenta su uso e inscribe directamente al estudiante en el curso.
* **Autenticación:** Protegido (`Bearer Token`).
* **Payload:**
```json
{
  "code": "MASTER100",
  "course_id": 1
}
```

---

### 7.3 `GET /me/coupons`
* **¿Para qué es?:** Sustituye la lista local `user_redeemed_coupons_list`. Muestra en la pantalla "Mis Cupones y Beneficios" todos los descuentos y becas canjeados por el estudiante.
* **Autenticación:** Protegido (`Bearer Token`).

---

## 8. Certificados y Diplomas con Código QR

### 8.1 `GET /certificates`
* **¿Para qué es?:** Sustituye los certificados de prueba hardcodeados (`MA-CERT-884102`). Devuelve los diplomas oficiales emitidos cuando el alumno alcanza el 100% del curso.
* **Autenticación:** Protegido (`Bearer Token`).
* **Tabla Backend sugerida:** `certificates` (`id`, `user_id`, `course_id`, `verification_uuid`, `recipient_name`, `issued_at`, `qr_code_url`, `certificate_pdf_url`).
* **Respuesta Exitosa (200 OK):**
```json
{
  "data": [
    {
      "id": 101,
      "title": "Certificado Profesional en Desarrollo Web Fullstack",
      "courseId": 1,
      "courseTitle": "Desarrollo Web Fullstack & Ciberseguridad",
      "recipientName": "Víctor Atala Lagunas",
      "verificationUuid": "MA-CERT-884102",
      "issuedAt": "2026-02-15T00:00:00Z",
      "qrCodeUrl": "https://masteracademy.mx/verify/MA-CERT-884102",
      "certificatePdfUrl": "https://masteracademy.mx/storage/certificates/MA-CERT-884102.pdf"
    }
  ]
}
```

---

### 8.2 `GET /certificates/verify/{uuid}`
* **¿Para qué es?:** Endpoint público para validación de diplomas. Cuando un reclutador o empresa escanea el código QR impreso en el PDF del certificado, este endpoint valida la autenticidad del folio.
* **Autenticación:** Pública (sin token).

---

## 9. Centro de Notificaciones

### 9.1 `GET /notifications`
* **¿Para qué es?:** Sustituye la lista fija de 3 notificaciones en memoria. Devuelve las alertas reales del alumno (bienvenida, nuevo contenido, recordatorios de estudio).
* **Autenticación:** Protegido (`Bearer Token`).
* **Tabla Backend sugerida:** `notifications` (`id`, `user_id`, `title`, `description`, `type`, `is_read`, `created_at`).
* **Respuesta Exitosa (200 OK):**
```json
{
  "data": [
    {
      "id": "notif_1",
      "title": "¡Bienvenido a Master Academy!",
      "description": "Explora nuestros cursos certificados e impulsa tu carrera profesional.",
      "type": "welcome",
      "isRead": false,
      "createdAt": "2026-03-01T12:00:00Z"
    }
  ]
}
```

---

### 9.2 `PATCH /notifications/{id}/read`
* **¿Para qué es?:** Marca una notificación específica como leída en la base de datos al ser pulsada.
* **Autenticación:** Protegido (`Bearer Token`).

---

### 9.3 `POST /notifications/read-all`
* **¿Para qué es?:** Marca todas las notificaciones pendientes como leídas al tocar el botón "Marcar todo como leído".
* **Autenticación:** Protegido (`Bearer Token`).

---

## 10. Centro de Soporte Técnico (Tickets)

### 10.1 `POST /support/tickets`
* **¿Para qué es?:** Sustituye el envío simulado con temporizador. Almacena en la base de datos la solicitud de ayuda del alumno y notifica al equipo de soporte.
* **Autenticación:** Pública / Protegido.
* **Tabla Backend sugerida:** `support_tickets` (`id`, `user_id`, `name`, `email`, `subject`, `message`, `status`, `created_at`).
* **Payload:**
```json
{
  "name": "Víctor Atala Lagunas",
  "email": "estudiante@masteracademy.mx",
  "subject": "Problema al generar diploma",
  "message": "He terminado el curso al 100% pero el botón de descarga no se activó."
}
```
* **Respuesta Exitosa (201 Created):**
```json
{
  "message": "Ticket registrado con éxito. Te responderemos en menos de 2 horas hábiles.",
  "ticket_id": 142
}
```

---

## 11. Comercio, Checkout y Pagos

### 11.1 `POST /courses/{courseId}/checkout`
* **¿Para qué es?:** Sustituye la orden local `ORD-...`. Calcula el precio final del curso en el servidor aplicando descuentos de cupones válidos y crea la orden en estado `pending`.
* **Autenticación:** Protegido (`Bearer Token`).
* **Tabla Backend sugerida:** `orders` (`id`, `order_number`, `user_id`, `course_id`, `subtotal`, `discount`, `total`, `coupon_id`, `status`).
* **Payload:**
```json
{
  "coupon_code": "PROMO20"
}
```
* **Respuesta Exitosa (201 Created):**
```json
{
  "order": {
    "id": 501,
    "order_number": "ORD-2026-8941",
    "course_id": 1,
    "subtotal": 399.00,
    "discount": 79.80,
    "total": 319.20,
    "status": "pending"
  }
}
```

---

### 11.2 `POST /orders/{orderId}/payments`
* **¿Para qué es?:** Sustituye la confirmación de pago offline simulada `TX-...`. Registra la transacción de la pasarela (Stripe, Mercado Pago o tarjeta) y matricula automáticamente al usuario en el curso.
* **Autenticación:** Protegido (`Bearer Token`).
* **Tabla Backend sugerida:** `payments` (`id`, `order_id`, `gateway_code`, `external_reference`, `status`, `amount`).
* **Payload:**
```json
{
  "gateway_code": "stripe",
  "external_reference": "ch_3Mv6782eZvKYlo2C1g9X8"
}
```
* **Respuesta Exitosa (200 OK):**
```json
{
  "is_success": true,
  "transaction_id": "TX-998241",
  "message": "Pago procesado y matrícula activada con éxito."
}
```
