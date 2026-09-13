# 📘 Master Academy API: Especificación Técnica de Endpoints (Producción)

> **Documento de Integración Backend & Mobile / Web**  
> **Versión:** 1.0.0 (API v1)  
> **Host Base:** `https://api.masteracademy.mx/api/v1` (o `http://localhost:8000/api/v1` en entorno local)  
> **Formato de Comunicación:** JSON (`Content-Type: application/json`, `Accept: application/json`)  
> **Autenticación:** Bearer Token JWT (`Authorization: Bearer <token>`) en endpoints protegidos.

---

## 📑 Tabla de Contenidos
1. [Autenticación y Perfil de Usuario](#1-autenticación-y-perfil-de-usuario)
2. [Catálogo de Cursos y Categorías](#2-catálogo-de-cursos-y-categorías)
3. [Estructura del Curso: Módulos, Lecciones y Recursos](#3-estructura-del-curso-módulos-lecciones-y-recursos)
4. [Progreso de Aprendizaje y Matrículas](#4-progreso-de-aprendizaje-y-matrículas)
5. [Calificaciones y Reseñas de Cursos (Estrellas y Opiniones)](#5-calificaciones-y-reseñas-de-cursos-estrellas-y-opiniones)
6. [Foros y Comentarios en Clase](#6-foros-y-comentarios-en-clase)
7. [Consultas con el Instructor (Tutorías / Q&A)](#7-consultas-con-el-instructor-tutorías--qa)
8. [Cuaderno de Notas del Estudiante](#8-cuaderno-de-notas-del-estudiante)
9. [Cupones, Becas y Descuentos](#9-cupones-becas-y-descuentos)
10. [Certificados y Diplomas Oficiales con Validación QR](#10-certificados-y-diplomas-oficiales-con-validación-qr)
11. [Centro de Notificaciones](#11-centro-de-notificaciones)
12. [Centro de Soporte Técnico (Tickets)](#12-centro-de-soporte-técnico-tickets)
13. [Comercio, Checkout y Pasarela de Pagos](#13-comercio-checkout-y-pasarela-de-pagos)

---

## 1. Autenticación y Perfil de Usuario

### 1.1 Iniciar Sesión
* **Método:** `POST`
* **Ruta:** `/auth/login`
* **Acceso:** Público
* **Propósito:** Autentica credenciales del usuario y genera un token JWT para peticiones posteriores.
* **Payload:**
```json
{
  "email": "estudiante@masteracademy.mx",
  "password": "Password123!"
}
```
* **Respuesta Exitosa (200 OK):**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": 1,
    "name": "Víctor Atala Lagunas",
    "email": "estudiante@masteracademy.mx",
    "avatar": "https://masteracademy.mx/storage/avatars/user_1.jpg"
  }
}
```

---

### 1.2 Registro de Alumno
* **Método:** `POST`
* **Ruta:** `/auth/register`
* **Acceso:** Público
* **Propósito:** Crea una nueva cuenta de estudiante en la plataforma.
* **Payload:**
```json
{
  "name": "Víctor Atala Lagunas",
  "email": "estudiante@masteracademy.mx",
  "password": "Password123!",
  "password_confirmation": "Password123!"
}
```
* **Respuesta Exitosa (201 Created):**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": 2,
    "name": "Víctor Atala Lagunas",
    "email": "estudiante@masteracademy.mx",
    "avatar": null
  }
}
```

---

### 1.3 Obtener Perfil del Usuario Autenticado
* **Método:** `GET`
* **Ruta:** `/auth/me`
* **Acceso:** Protegido (`Bearer Token`)
* **Propósito:** Recupera la información actualizada del alumno para la pantalla de Perfil.
* **Respuesta Exitosa (200 OK):**
```json
{
  "user": {
    "id": 1,
    "name": "Víctor Atala Lagunas",
    "email": "estudiante@masteracademy.mx",
    "avatar": "https://masteracademy.mx/storage/avatars/user_1.jpg",
    "created_at": "2026-01-10T12:00:00Z"
  }
}
```

---

### 1.4 Actualizar Información de Perfil
* **Método:** `PATCH`
* **Ruta:** `/auth/profile`
* **Acceso:** Protegido (`Bearer Token`)
* **Propósito:** Permite cambiar el nombre completo o correo del usuario.
* **Payload:**
```json
{
  "name": "Víctor Atala Lagunas",
  "email": "nuevo_correo@masteracademy.mx"
}
```

---

### 1.5 Actualizar Contraseña
* **Método:** `PATCH`
* **Ruta:** `/auth/password`
* **Acceso:** Protegido (`Bearer Token`)
* **Propósito:** Cambio seguro de contraseña validando la anterior.
* **Payload:**
```json
{
  "current_password": "Password123!",
  "password": "NuevaPassword456!",
  "password_confirmation": "NuevaPassword456!"
}
```

---

### 1.6 Cerrar Sesión
* **Método:** `POST`
* **Ruta:** `/auth/logout`
* **Acceso:** Protegido (`Bearer Token`)
* **Propósito:** Invalida el token JWT en el servidor.

---

### 1.7 Recuperación de Contraseña *(Nuevo)*
* **Método:** `POST`
* **Ruta:** `/auth/forgot-password`
* **Acceso:** Público
* **Propósito:** Envía un enlace o token temporal al correo registrado para restablecer la contraseña olvidada.
* **Payload:**
```json
{
  "email": "estudiante@masteracademy.mx"
}
```

---

### 1.8 Eliminación de Cuenta *(Nuevo - Requisito Google Play / App Store)*
* **Método:** `DELETE`
* **Ruta:** `/auth/account`
* **Acceso:** Protegido (`Bearer Token`)
* **Propósito:** Cumple con las pautas de privacidad de Apple y Google que exigen permitir al usuario eliminar su cuenta y datos personales.

---

## 2. Catálogo de Cursos y Categorías

### 2.1 Listado de Cursos Públicos
* **Método:** `GET`
* **Ruta:** `/courses`
* **Acceso:** Público
* **Query Parameters:**
  * `category` (opcional): Filtra por nombre o ID de categoría (ej. `Tecnologias`, `Seguridad Industrial`).
  * `search` (opcional): Término de búsqueda por título o descripción.
  * `page`, `limit` (opcional): Paginación de cursos.
* **Respuesta Exitosa (200 OK):**
```json
{
  "data": [
    {
      "id": 1,
      "title": "Desarrollo Web Fullstack & Ciberseguridad",
      "description": "Aprende arquitecturas web modernas, APIs seguras y mitigación de vulnerabilidades.",
      "category": {
        "id": 1,
        "name": "Tecnologías e información"
      },
      "instructor": {
        "name": "Víctor Atala Lagunas",
        "avatar": "https://masteracademy.mx/storage/avatars/inst_1.jpg",
        "bio": "Ingeniero de Software y Consultor de Seguridad."
      },
      "price": 399.00,
      "rating": 4.9,
      "reviews_count": 28,
      "students_count": 142,
      "duration": "28 horas",
      "level": "Intermedio",
      "thumbnail": "https://images.unsplash.com/photo-1550751827-4bd374c3f58b?w=600"
    }
  ]
}
```

---

### 2.2 Detalle de un Curso Específico
* **Método:** `GET`
* **Ruta:** `/courses/{id}`
* **Acceso:** Público
* **Propósito:** Entrega la información completa de la ficha técnica del curso antes de inscribirse.

---

### 2.3 Listado de Categorías
* **Método:** `GET`
* **Ruta:** `/categories`
* **Acceso:** Público
* **Propósito:** Alimenta los filtros de la pestaña "Categorías" y los selectores del panel de administración.
* **Respuesta Exitosa (200 OK):**
```json
{
  "data": [
    { "id": 1, "name": "Tecnologías e información", "courses_count": 5 },
    { "id": 2, "name": "Seguridad Industrial", "courses_count": 3 },
    { "id": 3, "name": "Salud y Prevención", "courses_count": 2 },
    { "id": 4, "name": "Negocios y Finanzas", "courses_count": 4 }
  ]
}
```

---

## 3. Estructura del Curso: Módulos, Lecciones y Recursos

### 3.1 Temario y Módulos del Curso
* **Método:** `GET`
* **Ruta:** `/courses/{courseId}/syllabi`
* **Acceso:** Público (con lecciones bloqueadas si no está inscrito, excepto las de preview)
* **Propósito:** Devuelve la lista jerárquica de módulos y sus lecciones.
* **Estructura de Respuesta (200 OK):**
```json
{
  "data": [
    {
      "id": 10,
      "title": "Módulo 1: Fundamentos y Arquitectura Segura",
      "order": 1,
      "lessons": [
        {
          "id": 101,
          "course_syllabus_id": 10,
          "title": "1.1 Introducción a Zero Trust y Estándares 2026",
          "description": "Conceptos clave del modelo de confianza cero.",
          "type": "video",
          "video_url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
          "duration_seconds": 720,
          "order": 1,
          "is_free_preview": true,
          "resources": [
            {
              "id": 501,
              "title": "Manual de Seguridad 2026 (PDF)",
              "file_url": "https://masteracademy.mx/storage/resources/manual_2026.pdf",
              "file_type": "pdf"
            }
          ]
        },
        {
          "id": 102,
          "course_syllabus_id": 10,
          "title": "1.2 Marco Normativo ISO 27001 (Lectura)",
          "description": "# Normativa Internacional ISO 27001\nTexto analítico...",
          "type": "reading",
          "video_url": null,
          "duration_seconds": 450,
          "order": 2,
          "is_free_preview": false,
          "resources": []
        }
      ]
    }
  ]
}
```

> **Nota de Videos por URL:** El campo `video_url` admite cualquier enlace compatible: YouTube (`watch`, `youtu.be`), Vimeo (`vimeo.com/XXXXX`), Google Drive (`/file/d/.../preview`) o URLs directas CDN (`.mp4`, `.m3u8`).

---

### 3.2 Recursos Descargables de Lección *(Nuevo)*
* **Método:** `GET`
* **Ruta:** `/lessons/{lessonId}/resources`
* **Acceso:** Protegido (requiere estar inscrito)
* **Propósito:** Lista guías en PDF, hojas de cálculo en Excel o plantillas adjuntas a la clase.

---

## 4. Progreso de Aprendizaje y Matrículas

### 4.1 Cursos en los que el Alumno está Inscrito
* **Método:** `GET`
* **Ruta:** `/me/courses/learning`
* **Acceso:** Protegido (`Bearer Token`)
* **Propósito:** Alimenta la pestaña "Mis Cursos" del estudiante con sus porcentajes reales calculados en la nube.
* **Respuesta Exitosa (200 OK):**
```json
{
  "data": [
    {
      "id": 1,
      "title": "Desarrollo Web Fullstack & Ciberseguridad",
      "progress_percentage": 60.0,
      "completed_lessons_count": 3,
      "total_lessons_count": 5,
      "thumbnail": "https://images.unsplash.com/photo-1550751827-4bd374c3f58b?w=600"
    }
  ]
}
```

---

### 4.2 Porcentaje de Progreso de un Curso
* **Método:** `GET`
* **Ruta:** `/courses/{courseId}/progress`
* **Acceso:** Protegido (`Bearer Token`)
* **Respuesta Exitosa (200 OK):**
```json
{
  "progress_percentage": 80.0,
  "completed_lessons_count": 4,
  "total_lessons_count": 5
}
```

---

### 4.3 Marcar Lección como Completada
* **Método:** `POST`
* **Ruta:** `/lessons/{lessonId}/complete`
* **Acceso:** Protegido (`Bearer Token`)
* **Propósito:** Registra el avance del alumno y actualiza en tiempo real el progreso global del curso.
* **Payload:**
```json
{
  "completed": true,
  "time_spent_seconds": 680
}
```

---

### 4.4 Matricular Usuario en un Curso
* **Método:** `POST`
* **Ruta:** `/courses/{courseId}/enroll`
* **Acceso:** Protegido (`Bearer Token`)
* **Propósito:** Matricula al usuario tras una validación de cupón/beca o confirmación de pago.
* **Payload:**
```json
{
  "code": "BECA100",
  "source": "code"
}
```

---

## 5. Calificaciones y Reseñas de Cursos (Estrellas y Opiniones)

### 5.1 Listar Reseñas de un Curso *(Nuevo)*
* **Método:** `GET`
* **Ruta:** `/courses/{courseId}/reviews`
* **Acceso:** Público
* **Propósito:** Sustituye el guardado local del teléfono. Muestra calificaciones reales dejadas por otros estudiantes en cualquier dispositivo o en la web.
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

### 5.2 Publicar Calificación y Reseña *(Nuevo)*
* **Método:** `POST`
* **Ruta:** `/courses/{courseId}/reviews`
* **Acceso:** Protegido (`Bearer Token`)
* **Propósito:** Permite al estudiante calificar el curso (1.0 a 5.0) y escribir su testimonio.
* **Payload:**
```json
{
  "rating": 5.0,
  "review_text": "Me encantó el curso, los laboratorios son muy prácticos.",
  "tags": ["Práctico", "Actualizado"]
}
```

---

## 6. Foros y Comentarios en Clase

### 6.1 Listar Comentarios y Preguntas de Clase *(Nuevo)*
* **Método:** `GET`
* **Ruta:** `/courses/{courseId}/comments`
* **Query Parameters:** `lesson_id` (opcional, para filtrar preguntas de una clase particular).
* **Acceso:** Protegido
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

### 6.2 Publicar Comentario o Pregunta *(Nuevo)*
* **Método:** `POST`
* **Ruta:** `/courses/{courseId}/comments`
* **Acceso:** Protegido
* **Payload:**
```json
{
  "lesson_id": 101,
  "parent_id": null,
  "content": "¿Este curso incluye certificado con validez oficial?"
}
```

---

### 6.3 Dar o Quitar "Me Gusta" a un Comentario *(Nuevo)*
* **Método:** `POST`
* **Ruta:** `/comments/{commentId}/like`
* **Acceso:** Protegido
* **Respuesta:** `{ "likes_count": 4, "is_liked": true }`

---

## 7. Consultas con el Instructor (Tutorías / Q&A)

### 7.1 Listar Mis Consultas al Profesor *(Nuevo)*
* **Método:** `GET`
* **Ruta:** `/me/inquiries`
* **Acceso:** Protegido
* **Propósito:** Muestra al alumno sus dudas enviadas y las respuestas dadas por el docente.

---

### 7.2 Enviar Consulta Directa al Profesor *(Nuevo)*
* **Método:** `POST`
* **Ruta:** `/courses/{courseId}/inquiries`
* **Acceso:** Protegido
* **Payload:**
```json
{
  "lesson_title": "1.1 Introducción a Zero Trust",
  "subject": "Duda con la implementación en Docker",
  "message": "Profesor, al configurar el proxy inverso obtuve un error de cabeceras..."
}
```

---

## 8. Cuaderno de Notas del Estudiante

### 8.1 Listar Todas las Notas Personales *(Nuevo)*
* **Método:** `GET`
* **Ruta:** `/me/notes`
* **Acceso:** Protegido
* **Propósito:** Permite que los apuntes tomados en el móvil se sincronicen en la web y viceversa.
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

### 8.2 Guardar o Editar Nota de una Lección *(Nuevo)*
* **Método:** `POST`
* **Ruta:** `/lessons/{lessonId}/notes`
* **Acceso:** Protegido
* **Payload:**
```json
{
  "course_id": 1,
  "content": "Conceptos de Zero Trust: verificación explícita y mínimo privilegio."
}
```

---

### 8.3 Eliminar Nota Personal *(Nuevo)*
* **Método:** `DELETE`
* **Ruta:** `/notes/{id}`
* **Acceso:** Protegido

---

## 9. Cupones, Becas y Descuentos

### 9.1 Validar Código de Cupón o Beca *(Nuevo)*
* **Método:** `POST`
* **Ruta:** `/coupons/validate`
* **Acceso:** Protegido
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

### 9.2 Canjear Cupón o Beca Directa *(Nuevo)*
* **Método:** `POST`
* **Ruta:** `/coupons/redeem`
* **Acceso:** Protegido
* **Payload:**
```json
{
  "code": "MASTER100",
  "course_id": 1
}
```
* **Propósito:** Si el cupón cubre el 100%, inscribe al alumno directamente al curso y registra el canje.

---

### 9.3 Listar Cupones Canjeados por el Alumno *(Nuevo)*
* **Método:** `GET`
* **Ruta:** `/me/coupons`
* **Acceso:** Protegido
* **Propósito:** Alimenta la vista "Mis Cupones y Beneficios" en el perfil del estudiante.

---

## 10. Certificados y Diplomas Oficiales con Validación QR

### 10.1 Listar Certificados Obtenidos
* **Método:** `GET`
* **Ruta:** `/certificates`
* **Acceso:** Protegido (`Bearer Token`)
* **Propósito:** Muestra diplomas acreditados al finalizar el 100% de un curso.
* **Respuesta Exitosa (200 OK):**
```json
{
  "data": [
    {
      "id": 101,
      "title": "Certificado de Acreditación Profesional en Desarrollo Web Fullstack",
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

### 10.2 Validación Pública de Certificado (Escaneo QR)
* **Método:** `GET`
* **Ruta:** `/certificates/verify/{uuid}`
* **Acceso:** Público (No requiere token)
* **Propósito:** Permite a empresas o reclutadores verificar la autenticidad del diploma escaneando el código QR impreso.

---

## 11. Centro de Notificaciones

### 11.1 Listar Notificaciones del Usuario *(Nuevo)*
* **Método:** `GET`
* **Ruta:** `/notifications`
* **Acceso:** Protegido
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

### 11.2 Marcar Notificación como Leída *(Nuevo)*
* **Método:** `PATCH`
* **Ruta:** `/notifications/{id}/read`
* **Acceso:** Protegido

---

### 11.3 Marcar Todas como Leídas *(Nuevo)*
* **Método:** `POST`
* **Ruta:** `/notifications/read-all`
* **Acceso:** Protegido

---

## 12. Centro de Soporte Técnico (Tickets)

### 12.1 Registrar Ticket de Ayuda *(Nuevo)*
* **Método:** `POST`
* **Ruta:** `/support/tickets`
* **Acceso:** Público / Protegido
* **Propósito:** Envía formalmente la solicitud de soporte a la base de datos y genera una notificación al equipo administrativo.
* **Payload:**
```json
{
  "name": "Víctor Atala Lagunas",
  "email": "estudiante@masteracademy.mx",
  "subject": "Problema al generar diploma",
  "message": "He terminado el curso al 100% pero el botón de descarga no se activó."
}
```

---

## 13. Comercio, Checkout y Pasarela de Pagos

### 13.1 Crear Intención de Compra / Orden de Checkout *(Nuevo)*
* **Método:** `POST`
* **Ruta:** `/courses/{courseId}/checkout`
* **Acceso:** Protegido (`Bearer Token`)
* **Propósito:** Calcula el total a pagar aplicando descuentos de cupones válidos y genera la orden en estado `pending`.
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

### 13.2 Confirmar / Procesar Pago de Orden *(Nuevo)*
* **Método:** `POST`
* **Ruta:** `/orders/{orderId}/payments`
* **Acceso:** Protegido (`Bearer Token`)
* **Propósito:** Registra la transacción de la pasarela (Stripe, Mercado Pago o tarjeta) y matricula automáticamente al usuario en `/me/courses/learning`.
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

---

## 🎯 Resumen de Estado de Endpoints

| Módulo | Endpoint | Estado | Impacto en App Móvil / Web |
| :--- | :--- | :--- | :--- |
| **Auth** | `/auth/login`, `/auth/register`, `/auth/me` | **Operativo** | Conectado con token JWT y persistencia segura. |
| **Auth** | `/auth/forgot-password`, `/auth/account` | **Nuevo** | Olvidé contraseña y eliminación de cuenta obligatoria por Apple/Google. |
| **Catálogo** | `/courses`, `/categories` | **Operativo** | Catálogo con filtrado inteligente en app móvil y web. |
| **Syllabus** | `/courses/{id}/syllabi` | **Operativo** | Lecciones con video streaming por URL (YouTube, Vimeo, Drive, MP4). |
| **Recursos** | `/lessons/{id}/resources` | **Nuevo** | Permite descargar PDFs y Excels adjuntos por lección. |
| **Progreso** | `/me/courses/learning`, `/courses/{id}/progress` | **Operativo** | Matrículas del alumno y porcentaje de avance en la nube. |
| **Reseñas** | `/courses/{id}/reviews` | **Nuevo** | Sustituye guardado local en teléfono para sincronizar opiniones entre dispositivos. |
| **Comentarios**| `/courses/{id}/comments` | **Nuevo** | Foros de debate y preguntas al instructor en tiempo real. |
| **Notas** | `/me/notes`, `/lessons/{id}/notes` | **Nuevo** | Sincroniza el Cuaderno de Notas del estudiante entre móvil y web. |
| **Cupones** | `/coupons/validate`, `/coupons/redeem` | **Nuevo** | Validación de becas en el servidor sin código duro en la app. |
| **Diplomas** | `/certificates`, `/certificates/verify/{uuid}` | **Nuevo** | Emisión automática de diploma al 100% y validación pública por QR. |
| **Soporte** | `/support/tickets` | **Nuevo** | Registro formal de tickets de atención a clientes. |
| **Pagos** | `/courses/{id}/checkout`, `/orders/{id}/payments`| **Nuevo** | Creación de orden y activación de matrícula tras pago. |
