import { ChangeDetectorRef, Component, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import {
  FormBuilder,
  ReactiveFormsModule,
  Validators
} from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';

import { AuthService, isStaffRole } from '../../core/services/auth.service';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './login.component.html',
  styleUrl: './login.component.scss'
})
export class LoginComponent {
  private readonly fb = inject(FormBuilder);
  private readonly auth = inject(AuthService);
  private readonly router = inject(Router);
  private readonly cdr = inject(ChangeDetectorRef);
  private readonly route = inject(ActivatedRoute);

  passwordVisible = false;
  loading = false;
  errorMessage = '';

  readonly sessionExpired =
    this.route.snapshot.queryParamMap.get('sessao') === 'expirada';

  readonly form = this.fb.nonNullable.group({
    email: ['', [Validators.required, Validators.email]],
    password: ['', Validators.required],
    remember: [false]
  });

  submit(): void {
    if (this.form.invalid || this.loading) {
      this.form.markAllAsTouched();
      return;
    }

    this.loading = true;
    this.errorMessage = '';

    const { email, password, remember } = this.form.getRawValue();

    this.auth.login(email, password, remember).subscribe({
      next: user => {
        this.loading = false;
        this.cdr.markForCheck();

        if (!isStaffRole(user.role)) {
          this.errorMessage =
            'Esta conta é de cliente. Use o app Edu para abrir e acompanhar chamados.';
          return;
        }

        this.router.navigateByUrl('/dashboard');
      },
      error: error => {
        this.loading = false;
        this.cdr.markForCheck();

        if (error?.status === 401) {
          this.errorMessage = 'E-mail ou senha inválidos.';
          return;
        }

        this.errorMessage =
          'Não consegui falar com a API. Confirme se o Spring está rodando na porta 8080.';
      }
    });
  }
}
