"""
Django REST Framework snippets for the new Settings screen.
Put these next to your existing /api/auth/me view and adjust the names
(your user model, serializer, url file) to match your project.
"""
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView


# 1) In your EXISTING "me" view, add a patch() method:
#
#     def patch(self, request):
#         first_name = (request.data.get("first_name") or "").strip()
#         if not first_name or len(first_name) > 50:
#             return Response({"error": "Enter a name (max 50 characters)."}, status=400)
#         request.user.first_name = first_name
#         request.user.save(update_fields=["first_name"])
#         return Response({"email": request.user.email, "first_name": first_name})


class ChangePasswordView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user = request.user
        old = request.data.get("old_password", "")
        new = request.data.get("new_password", "")
        if not user.check_password(old):
            return Response({"error": "Current password is incorrect."}, status=400)
        try:
            validate_password(new, user)  # uses AUTH_PASSWORD_VALIDATORS
        except ValidationError as e:
            return Response({"error": " ".join(e.messages)}, status=400)
        user.set_password(new)
        user.save()
        return Response({"ok": True})


class DeleteAccountView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user = request.user
        if not user.check_password(request.data.get("password", "")):
            return Response({"error": "Password is incorrect."}, status=400)
        # Make sure Document/Conversation/Quiz use on_delete=CASCADE on the
        # user ForeignKey, otherwise their rows (and uploaded PDFs) stay behind.
        user.delete()
        return Response({"ok": True})


# urls.py
#   path("api/auth/change-password", ChangePasswordView.as_view()),
#   path("api/auth/delete-account", DeleteAccountView.as_view()),
